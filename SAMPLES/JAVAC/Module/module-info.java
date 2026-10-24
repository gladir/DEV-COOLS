import com.acme.api.Greeter;
import java.lang.annotation.*;

@Deprecated
open module com.acme.app {
    requires java.logging;
    requires transitive java.sql;
    requires static java.compiler;
    exports com.acme.api;
    exports com.acme.impl to java.logging, java.sql;
    uses Greeter;
    uses java.sql.Driver;
    provides Greeter with com.acme.impl.Hello, com.acme.impl.Hi;
}
