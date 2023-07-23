
 
#include "RadioRoute.h"


configuration RadioRouteAppC {}
implementation {
  /****** COMPONENTS *****/
  components MainC, RadioRouteC as App;
  //add the other components here
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components ActiveMessageC;
  components LedsC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  
  /****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;
  /****** Wire the other interfaces down here *****/
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.Leds -> LedsC;
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  App.Packet -> AMSenderC;

}


