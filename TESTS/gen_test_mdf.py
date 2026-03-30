#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_test_mdf.py - Generate a minimal SQL Server .MDF file for testing SQLCMD.PAS

This script creates a valid .MDF binary file containing:
  - File Header page (page 0, type 15)
  - Boot page (page 9, type 13) with database name
  - System catalog pages:
    * sysschobjs (page 10, ObjId=34) - table/object definitions
    * syscolpars (page 11, ObjId=41) - column definitions
  - User data page (page 12, ObjId=256) - Employees table data

The generated file can be used with:
  SQLCMD -S test.mdf -q "SELECT * FROM Employees"
"""

import struct
import sys
import os

# ---- MDF Constants (matching SQLCMD.PAS) ----
MDF_PAGE_SIZE      = 8192
MDF_PAGE_HDR_SIZE  = 96
MDF_SLOT_ENTRY_SIZE = 2

# Page types
MDF_PT_DATA        = 1
MDF_PT_BOOT        = 13
MDF_PT_FILEHDR     = 15

# System object IDs
MDF_SYSOBJ_SYSSCHOBJS = 34
MDF_SYSOBJ_SYSCOLPARS = 41

# SQL Server data types (XT_*)
XT_INT       = 56
XT_VARCHAR   = 167
XT_NVARCHAR  = 231

# Row status bits
MDF_REC_HAS_NULL = 0x10
MDF_REC_HAS_VAR  = 0x20

# Our user table object ID
USER_TABLE_OBJID = 256


def write_word(buf, offset, value):
    """Write a 16-bit little-endian word into buf at offset."""
    struct.pack_into('<H', buf, offset, value & 0xFFFF)

def write_long(buf, offset, value):
    """Write a 32-bit little-endian long into buf at offset."""
    struct.pack_into('<I', buf, offset, value & 0xFFFFFFFF)

def write_byte(buf, offset, value):
    buf[offset] = value & 0xFF

def write_page_header(buf, page_type, obj_id, slot_cnt, free_data):
    """Write standard 96-byte page header."""
    write_byte(buf, 0, 1)          # HeaderVer = 1
    write_byte(buf, 1, page_type)  # PageType
    write_byte(buf, 2, 0)          # TypeFlagBits
    write_byte(buf, 3, 0)          # Level (leaf)
    write_word(buf, 4, 0)          # FlagBits
    write_word(buf, 6, 0)          # IndexId
    write_long(buf, 8, 0)          # PrevPage
    write_word(buf, 12, 0)         # PrevFile
    write_word(buf, 14, 0)         # PMinLen
    write_long(buf, 16, 0)         # NextPage
    write_word(buf, 20, 0)         # NextFile
    write_word(buf, 22, slot_cnt)  # SlotCnt
    write_long(buf, 24, obj_id)    # ObjId
    write_word(buf, 28, 0)         # FreeCnt
    write_word(buf, 30, free_data) # FreeData
    write_word(buf, 32, 0)         # ReservedCnt

def write_slot_array(buf, slots):
    """Write slot array at end of page (row offsets, from end of page)."""
    for i, row_ofs in enumerate(slots):
        ofs = MDF_PAGE_SIZE - MDF_SLOT_ENTRY_SIZE * (i + 1)
        write_word(buf, ofs, row_ofs)

def encode_utf16le(s):
    """Encode string as UTF-16 LE bytes."""
    return s.encode('utf-16-le')


# ---- Row builders ----

def build_sysschobjs_row(obj_id, schema_id, obj_type, parent_id, name):
    """
    Build a sysschobjs row (system objects catalog).

    Fixed part layout (23 bytes):
      +0: StatusA (1 byte) = 0x30 (HasNullBmp + HasVarCols)
      +1: StatusB (1 byte) = 0x00
      +2: FixedLen (2 bytes, word) = 23
      +4: ObjectId (4 bytes)
      +8: SchemaId (4 bytes)
     +12: NSClass (1 byte) = 0
     +13: Status (4 bytes) = 0
     +17: Type[0] (1 byte)
     +18: Type[1] (1 byte)
     +19: ParentId (4 bytes)

    Variable part:
      ColCount(2) + NullBitmap(1) + VarCnt(2) + Offsets(2) + Name(UTF-16 LE)
    """
    fixed_len = 23
    name_bytes = encode_utf16le(name)

    # Total columns in sysschobjs row: 7 fixed + 1 variable = 8
    col_count = 8
    null_bmp_sz = (col_count + 7) // 8  # = 1
    var_cnt = 1  # 1 variable column (Name)

    # Calculate offsets
    # After fixed data: ColCount(2) + NullBmp(1) + VarCnt(2) + Offsets(1*2=2) + NameData
    var_data_start = fixed_len + 2 + null_bmp_sz + 2 + var_cnt * 2
    name_end_ofs = var_data_start + len(name_bytes)

    total_len = name_end_ofs
    row = bytearray(total_len)

    # Fixed part
    row[0] = MDF_REC_HAS_NULL | MDF_REC_HAS_VAR  # StatusA = 0x30
    row[1] = 0x00  # StatusB
    struct.pack_into('<H', row, 2, fixed_len)  # FixedLen
    struct.pack_into('<I', row, 4, obj_id)     # ObjectId
    struct.pack_into('<I', row, 8, schema_id)  # SchemaId
    row[12] = 0                                 # NSClass
    struct.pack_into('<I', row, 13, 0)         # Status
    row[17] = ord(obj_type[0]) if len(obj_type) > 0 else 0x20  # Type[0]
    row[18] = ord(obj_type[1]) if len(obj_type) > 1 else 0x20  # Type[1]
    struct.pack_into('<I', row, 19, parent_id) # ParentId

    # Variable part
    ofs = fixed_len
    struct.pack_into('<H', row, ofs, col_count)  # ColCount
    ofs += 2
    row[ofs] = 0x00  # NULL bitmap (no NULLs)
    ofs += null_bmp_sz
    struct.pack_into('<H', row, ofs, var_cnt)    # VarCnt
    ofs += 2
    # Offset array: end of name data relative to row start
    struct.pack_into('<H', row, ofs, name_end_ofs)
    ofs += 2
    # Name data (UTF-16 LE)
    row[ofs:ofs + len(name_bytes)] = name_bytes

    return bytes(row)


def build_syscolpars_row(obj_id, col_num, col_id, xtype, max_len, prec, scale, name):
    """
    Build a syscolpars row (column metadata).

    Fixed part layout (31 bytes):
      +0: StatusA (1 byte) = 0x30
      +1: StatusB (1 byte) = 0x00
      +2: FixedLen (2 bytes) = 31
      +4: ObjectId (4 bytes)
      +8: ColNum (2 bytes)
     +10: ColumnId (4 bytes)
     +14: XType (1 byte)
     +15: UType (1 byte)
     +16: padding (3 bytes)
     +19: MaxLen (2 bytes)
     +21: Prec (1 byte)
     +22: Scale (1 byte)
     +23: CollId (4 bytes)
     +27: Status (4 bytes)

    Variable part:
      ColCount(2) + NullBitmap(2) + VarCnt(2) + Offsets(2) + Name(UTF-16 LE)
    """
    fixed_len = 31
    name_bytes = encode_utf16le(name)

    # Total columns in syscolpars row: 10 fixed + 1 variable = 11
    col_count = 11
    null_bmp_sz = (col_count + 7) // 8  # = 2
    var_cnt = 1  # 1 variable column (Name)

    var_data_start = fixed_len + 2 + null_bmp_sz + 2 + var_cnt * 2
    name_end_ofs = var_data_start + len(name_bytes)

    total_len = name_end_ofs
    row = bytearray(total_len)

    # Fixed part
    row[0] = MDF_REC_HAS_NULL | MDF_REC_HAS_VAR
    row[1] = 0x00
    struct.pack_into('<H', row, 2, fixed_len)
    struct.pack_into('<I', row, 4, obj_id)
    struct.pack_into('<H', row, 8, col_num)
    struct.pack_into('<I', row, 10, col_id)
    row[14] = xtype
    row[15] = xtype  # UType = XType for simplicity
    row[16] = 0; row[17] = 0; row[18] = 0  # padding
    struct.pack_into('<H', row, 19, max_len)
    row[21] = prec
    row[22] = scale
    struct.pack_into('<I', row, 23, 0)  # CollId
    struct.pack_into('<I', row, 27, 1 if xtype in (XT_VARCHAR, XT_NVARCHAR) else 0)  # Status: nullable for strings

    # Variable part
    ofs = fixed_len
    struct.pack_into('<H', row, ofs, col_count)
    ofs += 2
    row[ofs] = 0x00; row[ofs+1] = 0x00  # NULL bitmap
    ofs += null_bmp_sz
    struct.pack_into('<H', row, ofs, var_cnt)
    ofs += 2
    struct.pack_into('<H', row, ofs, name_end_ofs)
    ofs += 2
    row[ofs:ofs + len(name_bytes)] = name_bytes

    return bytes(row)


def build_user_data_row(int_values, str_values, col_types):
    """
    Build a user data row with mixed INT and VARCHAR columns.

    col_types: list of (xtype, is_fixed) for each column in order
    int_values: dict of {col_index: int_value} for fixed INT columns
    str_values: dict of {col_index: str_value} for variable VARCHAR columns

    Row layout:
      +0: StatusA = 0x30
      +1: StatusB = 0x00
      +2: FixedLen (2 bytes)
      +4: fixed column data (4 bytes per INT)
      After fixed: ColCount(2) + NullBmp + VarCnt(2) + Offsets + VarData
    """
    num_cols = len(col_types)
    fixed_cols = [(i, ct) for i, ct in enumerate(col_types) if ct[1]]
    var_cols = [(i, ct) for i, ct in enumerate(col_types) if not ct[1]]

    # Fixed data: 4 bytes header + 4 bytes per fixed column
    fixed_data_size = 4  # StatusA + StatusB + FixedLen
    for i, ct in fixed_cols:
        if ct[0] == XT_INT:
            fixed_data_size += 4
    fixed_len = fixed_data_size

    null_bmp_sz = (num_cols + 7) // 8
    var_cnt = len(var_cols)

    # Calculate variable data
    var_data_list = []
    for i, ct in var_cols:
        if i in str_values:
            var_data_list.append(str_values[i].encode('ascii'))
        else:
            var_data_list.append(b'')

    # Calculate total variable data + offsets
    var_data_start = fixed_len + 2 + null_bmp_sz + 2 + var_cnt * 2
    cumulative_end = var_data_start
    var_offsets = []
    for data in var_data_list:
        cumulative_end += len(data)
        var_offsets.append(cumulative_end)

    total_len = cumulative_end
    row = bytearray(total_len)

    # Write fixed part
    row[0] = MDF_REC_HAS_NULL | MDF_REC_HAS_VAR
    row[1] = 0x00
    struct.pack_into('<H', row, 2, fixed_len)

    # Write fixed column data
    fix_ofs = 4
    for i, ct in fixed_cols:
        if ct[0] == XT_INT:
            val = int_values.get(i, 0)
            struct.pack_into('<i', row, fix_ofs, val)  # signed 32-bit
            fix_ofs += 4

    # Write variable part
    ofs = fixed_len
    struct.pack_into('<H', row, ofs, num_cols)  # ColCount
    ofs += 2
    # NULL bitmap
    for b in range(null_bmp_sz):
        row[ofs + b] = 0x00
    ofs += null_bmp_sz
    struct.pack_into('<H', row, ofs, var_cnt)  # VarCnt
    ofs += 2
    # Offset array
    for vo in var_offsets:
        struct.pack_into('<H', row, ofs, vo)
        ofs += 2
    # Variable data
    for data in var_data_list:
        row[ofs:ofs + len(data)] = data
        ofs += len(data)

    return bytes(row)


def create_page(page_type=0, obj_id=0):
    """Create a blank 8192-byte page with the given type and obj_id."""
    buf = bytearray(MDF_PAGE_SIZE)
    if page_type > 0:
        write_page_header(buf, page_type, obj_id, 0, MDF_PAGE_HDR_SIZE)
    return buf


def add_rows_to_page(page_buf, rows):
    """Add rows to a data page, updating header and slot array."""
    slot_offsets = []
    data_ofs = MDF_PAGE_HDR_SIZE

    for row_data in rows:
        if data_ofs + len(row_data) > MDF_PAGE_SIZE - len(rows) * MDF_SLOT_ENTRY_SIZE:
            break
        page_buf[data_ofs:data_ofs + len(row_data)] = row_data
        slot_offsets.append(data_ofs)
        data_ofs += len(row_data)

    # Update slot count and free data
    write_word(page_buf, 22, len(slot_offsets))  # SlotCnt
    write_word(page_buf, 30, data_ofs)           # FreeData

    # Write slot array
    write_slot_array(page_buf, slot_offsets)

    return page_buf


def create_boot_page(db_name):
    """Create Boot page (page 9, type 13) with database name."""
    buf = create_page(MDF_PT_BOOT, 0)

    # Boot page data starts at offset 96
    boot_data_ofs = MDF_PAGE_HDR_SIZE

    # dbi_version at offset 96+0
    write_long(buf, boot_data_ofs + 0, 904)  # SQL Server 2019 version

    # dbi_createVersion at offset 96+4
    write_long(buf, boot_data_ofs + 4, 904)

    # dbi_status at offset 96+24
    write_long(buf, boot_data_ofs + 24, 0)

    # dbi_dbname at offset 96+100 (UTF-16 LE, up to 128 chars)
    name_utf16 = encode_utf16le(db_name)
    name_ofs = boot_data_ofs + 100
    buf[name_ofs:name_ofs + len(name_utf16)] = name_utf16

    # dbi_dbid at offset 96+356
    write_word(buf, boot_data_ofs + 356, 5)  # DBID = 5

    # dbi_cmptlevel at offset 96+396
    write_word(buf, boot_data_ofs + 396, 150)  # Compatibility level 150

    return buf


def generate_mdf(output_path, db_name='TestDB'):
    """Generate a complete MDF file with Employees table and sample data."""

    # ---- Define table structure ----
    # Employees table with 5 columns:
    #   EmployeeId INT (fixed, col 0)
    #   Salary INT (fixed, col 1)
    #   FirstName VARCHAR(50) (variable, col 2)
    #   LastName VARCHAR(50) (variable, col 3)
    #   Department VARCHAR(50) (variable, col 4)

    columns = [
        {'name': 'EmployeeId',  'xtype': XT_INT,     'max_len': 4,   'prec': 0, 'scale': 0, 'is_fixed': True},
        {'name': 'Salary',      'xtype': XT_INT,     'max_len': 4,   'prec': 0, 'scale': 0, 'is_fixed': True},
        {'name': 'FirstName',   'xtype': XT_VARCHAR, 'max_len': 50,  'prec': 0, 'scale': 0, 'is_fixed': False},
        {'name': 'LastName',    'xtype': XT_VARCHAR, 'max_len': 50,  'prec': 0, 'scale': 0, 'is_fixed': False},
        {'name': 'Department',  'xtype': XT_VARCHAR, 'max_len': 50,  'prec': 0, 'scale': 0, 'is_fixed': False},
    ]

    # Sample employee data
    employees = [
        {'EmployeeId': 1,  'Salary': 75000,  'FirstName': 'Alice',   'LastName': 'Martin',   'Department': 'Engineering'},
        {'EmployeeId': 2,  'Salary': 62000,  'FirstName': 'Bob',     'LastName': 'Dupont',   'Department': 'Sales'},
        {'EmployeeId': 3,  'Salary': 85000,  'FirstName': 'Charlie', 'LastName': 'Bernard',  'Department': 'Engineering'},
        {'EmployeeId': 4,  'Salary': 45000,  'FirstName': 'Diana',   'LastName': 'Leroy',    'Department': 'Marketing'},
        {'EmployeeId': 5,  'Salary': 92000,  'FirstName': 'Eve',     'LastName': 'Moreau',   'Department': 'Engineering'},
        {'EmployeeId': 6,  'Salary': 55000,  'FirstName': 'Frank',   'LastName': 'Simon',    'Department': 'Sales'},
        {'EmployeeId': 7,  'Salary': 48000,  'FirstName': 'Grace',   'LastName': 'Laurent',  'Department': 'Marketing'},
        {'EmployeeId': 8,  'Salary': 71000,  'FirstName': 'Henri',   'LastName': 'Roux',     'Department': 'Engineering'},
    ]

    # ---- Build pages ----
    pages = []

    # Page 0: File Header (type 15)
    pages.append(create_page(MDF_PT_FILEHDR, 0))

    # Pages 1-8: Filler (empty data pages or zero pages)
    for i in range(1, 9):
        pages.append(create_page(0, 0))

    # Page 9: Boot page (type 13)
    pages.append(create_boot_page(db_name))

    # Page 10: sysschobjs (ObjId=34) - table definitions
    sysschobjs_page = create_page(MDF_PT_DATA, MDF_SYSOBJ_SYSSCHOBJS)
    sysschobjs_rows = [
        build_sysschobjs_row(USER_TABLE_OBJID, 1, 'U ', 0, 'Employees'),
    ]
    add_rows_to_page(sysschobjs_page, sysschobjs_rows)
    pages.append(sysschobjs_page)

    # Page 11: syscolpars (ObjId=41) - column definitions
    syscolpars_page = create_page(MDF_PT_DATA, MDF_SYSOBJ_SYSCOLPARS)
    syscolpars_rows = []
    for col_idx, col in enumerate(columns):
        syscolpars_rows.append(
            build_syscolpars_row(
                obj_id=USER_TABLE_OBJID,
                col_num=col_idx + 1,
                col_id=col_idx + 1,
                xtype=col['xtype'],
                max_len=col['max_len'],
                prec=col['prec'],
                scale=col['scale'],
                name=col['name']
            )
        )
    add_rows_to_page(syscolpars_page, syscolpars_rows)
    pages.append(syscolpars_page)

    # Page 12: User data - Employees (ObjId=USER_TABLE_OBJID)
    data_page = create_page(MDF_PT_DATA, USER_TABLE_OBJID)
    col_types = [(col['xtype'], col['is_fixed']) for col in columns]

    data_rows = []
    for emp in employees:
        row = build_user_data_row(
            int_values={0: emp['EmployeeId'], 1: emp['Salary']},
            str_values={2: emp['FirstName'], 3: emp['LastName'], 4: emp['Department']},
            col_types=col_types
        )
        data_rows.append(row)
    add_rows_to_page(data_page, data_rows)
    pages.append(data_page)

    # ---- Write MDF file ----
    with open(output_path, 'wb') as f:
        for page in pages:
            f.write(bytes(page))

    file_size = len(pages) * MDF_PAGE_SIZE
    print(f'Generated {output_path}')
    print(f'  Database: {db_name}')
    print(f'  Pages: {len(pages)}')
    print(f'  Size: {file_size} bytes')
    print(f'  Table: Employees ({len(employees)} rows, {len(columns)} columns)')
    print(f'  Columns: {", ".join(c["name"] for c in columns)}')

    return output_path


if __name__ == '__main__':
    output = sys.argv[1] if len(sys.argv) > 1 else '/tmp/test_sqlcmd.mdf'
    generate_mdf(output)
