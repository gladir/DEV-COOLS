package java.time;
import java.io.*;
public final class Ser implements Externalizable {
    private static final long serialVersionUID = -7683839454370182990L;
    static final byte DURATION_TYPE = 1;
    static final byte INSTANT_TYPE = 2;
    static final byte LOCAL_DATE_TYPE = 3;
    static final byte LOCAL_TIME_TYPE = 4;
    static final byte LOCAL_DATE_TIME_TYPE = 5;
    static final byte PERIOD_TYPE = 14;
    static final byte YEAR_TYPE = 11;
    private byte type;
    private Object object;
    public Ser() { }
    Ser(byte type, Object object) { this.type = type; this.object = object; }
    public void writeExternal(ObjectOutput out) throws IOException {
        out.writeByte(type);
        switch (type) {
            case DURATION_TYPE: ((Duration) object).writeExternal(out); break;
            case INSTANT_TYPE: ((Instant) object).writeExternal(out); break;
            case LOCAL_DATE_TYPE: ((LocalDate) object).writeExternal(out); break;
            case LOCAL_TIME_TYPE: ((LocalTime) object).writeExternal(out); break;
            case LOCAL_DATE_TIME_TYPE: ((LocalDateTime) object).writeExternal(out); break;
            case PERIOD_TYPE: ((Period) object).writeExternal(out); break;
            case YEAR_TYPE: ((Year) object).writeExternal(out); break;
            default: throw new InvalidClassException("Unknown serialized type");
        }
    }
    public void readExternal(ObjectInput in) throws IOException, ClassNotFoundException {
        type = in.readByte();
        switch (type) {
            case DURATION_TYPE: object = Duration.readExternal(in); break;
            case INSTANT_TYPE: object = Instant.readExternal(in); break;
            case LOCAL_DATE_TYPE: object = LocalDate.readExternal(in); break;
            case LOCAL_TIME_TYPE: object = LocalTime.readExternal(in); break;
            case LOCAL_DATE_TIME_TYPE: object = LocalDateTime.readExternal(in); break;
            case PERIOD_TYPE: object = Period.readExternal(in); break;
            case YEAR_TYPE: object = Year.readExternal(in); break;
            default: throw new StreamCorruptedException("Unknown serialized type");
        }
    }
    private Object readResolve() { return object; }
}
