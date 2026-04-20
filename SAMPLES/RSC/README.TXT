RSC Sample Files - GEM Resource Format (Atari ST)
==================================================

This directory contains sample RSC files for testing the WORKSHOP
resource editor's GEM/RSC import functionality.

Files:
------

SIMPLE.RSC - Simple dialog box with one OK button
             - 1 tree (dialog)
             - 2 objects: G_BOX (root), G_BUTTON (OK)
             
MENU.RSC   - Menu bar example
             - 1 tree (menu structure)
             - 7 objects: menu bar, titles, dropdowns, items

RSC File Format Overview:
-------------------------

The RSC format is used by GEM (Graphics Environment Manager) on
Atari ST computers. Key characteristics:

- Big-endian byte order (68000 processor)
- 36-byte header with offsets to data sections
- Object trees define UI structure (dialogs, menus, alerts)

Header structure (36 bytes):
  Word vrsn      - Version (usually 0)
  Word object_   - Offset to OBJECT array
  Word tedinfo   - Offset to TEDINFO array  
  Word iconblk   - Offset to ICONBLK array
  Word bitblk    - Offset to BITBLK array
  Word frstr     - Offset to free strings
  Word string_   - Offset to first string
  Word imdata    - Offset to image data
  Word frimg     - Offset to free images
  Word trindex   - Offset to tree index
  Word nobs      - Number of objects
  Word ntree     - Number of trees
  Word nted      - Number of TEDINFO structures
  Word nib       - Number of ICONBLK structures
  Word nbb       - Number of BITBLK structures
  Word nstring   - Number of strings
  Word nimages   - Number of images
  Word rssize    - Total file size

Object types:
  G_BOX     = 20   - Box (container)
  G_TEXT    = 21   - Text (TEDINFO)
  G_BOXTEXT = 22   - Boxed text
  G_IMAGE   = 23   - Bitmap image
  G_USERDEF = 24   - User-defined
  G_IBOX    = 25   - Invisible box
  G_BUTTON  = 26   - Button
  G_BOXCHAR = 27   - Box with character
  G_STRING  = 28   - String
  G_FTEXT   = 29   - Formatted text
  G_FBOXTEXT= 30   - Formatted boxed text
  G_ICON    = 31   - Icon
  G_TITLE   = 32   - Menu title

Usage:
------

Load these files in WORKSHOP using:
  File -> Import -> GEM RSC...

Or from command line:
  WORKSHOP SIMPLE.RSC

The imported resources will be converted to Windows resource
format for editing.
