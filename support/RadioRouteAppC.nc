
#include "RadioRoute.h"

configuration RadioRouteAppC {}
implementation {
 

  /****** COMPONENTS *****/

  components MainC, ActiveMessageC, RandomC, RadioRouteC as App;
  
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;


  /****** INTERFACES *****/
  
  App.Boot -> MainC.Boot;
  
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.Packet -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  App.Timer2 -> Timer2;
  
  App.Random -> RandomC;

}
