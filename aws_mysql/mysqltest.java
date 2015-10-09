import  java.util.*;
import  java.sql.*;

public  class	mysqltest {

    static  public  void  getDBConnection() {
        System.out.println ("Start of getDBConnection.");

        Connection  conn        = null;
        String      url         = "jdbc:mysql://localhost:3306/";
        String      dbName      = "pims";
        String      driver      = "com.mysql.jdbc.Driver";
        String      userName    = "pimsadmin";  // blanked for publication
        String      password    = "userpw";

        try {
            Class.forName (driver).newInstance();
            System.out.println ("driver.newInstance gotten.");
            conn = DriverManager.getConnection (url+dbName, userName, password);
            System.out.println ("Connection gotten: " + conn + ".");
            Statement sql     = conn.createStatement ();
            ResultSet results = sql.executeQuery ("use " + dbName + ";");
        }
        catch (Exception ex) {
            System.out.println ("*** Got exception.");
            ex.printStackTrace();
        }
    }

    public static void main(String args[]) {
        System.out.println ("Main started.");
        mysqltest.getDBConnection();
    }
}
