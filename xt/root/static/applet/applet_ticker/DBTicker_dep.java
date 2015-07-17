import java.applet.Applet;
import java.sql.*;
import java.awt.*;
import java.io.*;
import java.util.*;


public class DBTicker extends Applet implements Runnable {

   private Thread updateThread;
   int updateInterval;
   String str;
   int key;
   int xpos;
   int ypos;

   public void init() {
      key = 0;
      str = getData();
      xpos = 110;
      ypos = 20;
      updateInterval = 20;
   }

   public void run() {
 
      while( Thread.currentThread() == updateThread ){

         try {
            Thread.sleep( updateInterval );
         }
         catch ( InterruptedException e ){
            return; 
         }

         if(xpos <= -5){ 
            str = getData();
            xpos = 110;
         }
         else if( xpos == 55 ){
            try {
               Thread.sleep( updateInterval * 100 );
            }
            catch ( InterruptedException e ){
               return; 
            }
            xpos = xpos - 1;
         }
         else{ xpos = xpos - 1; }

         repaint();
      }
   }

   public void paint( Graphics g ) {

      g.setColor( Color.black);
      g.drawString(str, ypos, xpos);
   }

   public void start(){
      if( updateThread == null ){
         updateThread = new Thread(this);
         updateThread.start();
      }
   }

   public void stop(){
      if( updateThread != null ){
         Thread runner = updateThread;
         str = "I have stopped";
         repaint();
         updateThread = null;
         runner.interrupt();
      }
   }

   private String getData() { 

//      Connection db;
//      Statement sql;
      String ordercount = "";
      Hashtable hash = new Hashtable();
//   
//      String database = "upload";
//      String username = "postgres";
//      String password = "postgres";
//   
//      try { 
//         Class.forName("org.postgresql.Driver");
//         db = DriverManager.getConnection("jdbc:postgresql:" + database, username, password);
//         sql = db.createStatement();
//         String sqlText = "select count(*) from orders";
//         ResultSet results = sql.executeQuery(sqlText);
//         if(results != null){
//            while( results.next() ){
//               ordercount = results.getString("count");
//            }
//         }
//         results.close();
//
//      }
//      catch( Exception e) {
//         System.err.println(e.getMessage());
//      }

      File datafile = new File("info.txt");
      try{
         FileReader fr = new FileReader(datafile);
         BufferedReader in = new BufferedReader( fr ); 
         String line;
         while( (line = in.readLine() ) != null ){
            String [] tmp = null;
            tmp = line.split("\t");
            hash.put( tmp[0], tmp[1] );
         }
         in.close();
      }
      catch(Exception e){
         System.err.println(e.getMessage());
      }
 
      if(key == 3){ key = 1; }
      else{ key = key + 1; }
      String hashkey = "" + key;

      return (String)hash.get(hashkey);

   }
}

