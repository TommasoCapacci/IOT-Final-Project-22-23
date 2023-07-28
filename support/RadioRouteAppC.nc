#include "RadioRoute.h"

configuration RadioRouteAppC {}
implementation {
 

  /****** COMPONENTS *****/

  components MainC, RadioRouteC as App;
  // add other components down here
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components ActiveMessageC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components RandomC;


  /****** INTERFACES *****/
  
  App.Boot -> MainC.Boot;
  // wire other interfaces down here
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  App.Packet -> AMSenderC;
  App.Random -> RandomC;

}
