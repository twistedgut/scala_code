
public class Clock extends DBTicker {
   public void paint( java.awt.Graphics g ){
      g.drawString( new java.util.Date().toString(), 10, 25 );
   }
}

