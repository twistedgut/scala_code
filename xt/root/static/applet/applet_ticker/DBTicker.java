import java.applet.Applet;
import java.sql.*;
import java.awt.*;
import java.io.*;
import java.util.*;
import java.net.*;

public class DBTicker extends Applet implements Runnable {

   private Thread updateThread;
   int updateInterval;
   Hashtable hash;
   String latestorder; 
   String totalval; 
   String ordernum; 
   int xpos1;
   int xpos2;
   int xpos3;
   int count;
   Font f;

   public void init() {
      hash = new Hashtable();
      getData();
      xpos1 = 55;
      xpos2 = 55;
      xpos3 = 55; 
      latestorder = (String)hash.get("latestorder"); 
      totalval = (String)hash.get("totalvalorder"); 
      ordernum = (String)hash.get("ordernum"); 
      updateInterval = 20;
      f = new Font("Verdana", Font.BOLD, 16 );
      count = 0;
   }

   public void run() {

      int updatelatestorder = 0; 
      int updatetotalval = 0; 
      int updateordernum = 0; 

      while( Thread.currentThread() == updateThread ){

         try {
            Thread.sleep( updateInterval );
         }
         catch ( InterruptedException e ){
            return; 
         }

         if(count == 250){
            getData();

            if( latestorder.compareTo( (String)hash.get("latestorder") ) != 0 && updatelatestorder == 0 ){ 
               updatelatestorder = 1; 
               xpos1 = 54;
            }
            if( ordernum.compareTo( (String)hash.get("ordernum") ) != 0 && updateordernum == 0 ){ 
               updateordernum = 1; 
               xpos2 = 54;
            }
            count = 0;
         }

         if(xpos1 == 55 ){ updatelatestorder = 0; }
         if(xpos2 == 55 ){ updateordernum = 0; }

         if( updatelatestorder == 1 ){
            if(xpos1 <= -5){ 
               xpos1 = 110;
               latestorder = (String)hash.get("latestorder");
            }
            else{ xpos1--; }
         }
         if( updateordernum == 1 ){
            if(xpos2 <= -5){ 
               xpos2 = 110;
               ordernum = (String)hash.get("ordernum");
            }
            else{ xpos2--; }
         }

         if( updatelatestorder == 1 || updateordernum == 1 ){ repaint(); }

         count++;
      }
   }

   public void paint( Graphics g ) {
      g.setFont(f);
      setBackground( Color.black );
      g.setColor( Color.white );
      g.drawString( latestorder, 20, xpos1 );
      g.drawString( ordernum, 120, xpos2);
      g.drawString( (String)hash.get("totalval"), 160, xpos3);
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
         updateThread = null;
         runner.interrupt();
      }
   }

   private void getData() { 

      //FileReader fr = new FileReader(datafile);
      //File datafile = new File("info.txt");

      try{
         String line;
         URL datafile = new URL("file:///Users/mryall/projects/java/applet_ticker/info.txt");
         BufferedReader data = new BufferedReader( new InputStreamReader( datafile.openStream() ) );
         while ( (line = data.readLine() ) != null) {
            String [] tmp = null;
            tmp = line.split("\t");
            hash.put( tmp[0], tmp[1] );
         }
         data.close();

         //while( (line = in.readLine() ) != null ){
         //   String [] tmp = null;
         //   tmp = line.split("\t");
         //   hash.put( tmp[0], tmp[1] );
         //}
         //in.close();
      }
      catch(Exception e){
         System.err.println(e.getMessage());
      }
   }

}

