
#include "Timer.h"
#include "RadioRoute.h"


module RadioRouteC @safe() {
  uses {
  
  
    /****** INTERFACES *****/
    
	interface Boot;
    interface Receive;
    interface AMSend;
    interface SplitControl as AMControl;
    interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;
    interface Timer<TMilli> as Timer2;
    interface Packet;
    interface Random;
  }
}
implementation {


  // Constants
  
  enum{
  	PACKET_POOL_SIZE = 20
  };
  
  
  // Variables
  
  message_t* packetsPool[PACKET_POOL_SIZE];
  uint16_t addressesPool[PACKET_POOL_SIZE];
  uint8_t head = 0;
  uint8_t tail = 0;
  
  
  // Functions prototypes
  
  bool poolEmpty ();
  void generate_send (uint16_t address, message_t* packet);
  
  
  // Tasks prototypes
  
  task void radioSendTask();
  
  
  // Functions
  
  bool poolEmpty (){
  	return (head == tail);
  }
  
  void generate_send (uint16_t address, message_t* packet){
  	atomic{
  	  packetsPool[head] = packet;
  	  addressesPool[head] = address;
 	  head = (head + 1) % PACKET_POOL_SIZE;
  	}
  	
  	post radioSendTask(); 
  } 
  
  
  // Tasks
  
  task void radioSendTask(){
  	if (call AMSend.send(addressesPool[tail], packetsPool[tail], sizeof(radio_route_msg_t)) == SUCCESS)
	  dbg("Radio_send", "Sending packet to %d at time %s:\n", addressesPool[tail], sim_time_string());
	else
	  post radioSendTask();
  }
  
  
  // Events
  
  event void Boot.booted() {
    dbg("Boot","Application booted.\n");
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
  	uint8_t i;
  	message_t* message;
  	radio_route_msg_t* packet;
  
	if (err == SUCCESS){
      dbg("Radio","Radio on.\n");
      if (TOS_NODE_ID == 1){
        for(i = 2; i <= 9; i++){
          message = (message_t*) malloc(sizeof(message_t));
          packet = (radio_route_msg_t*)call Packet.getPayload(message, sizeof(radio_route_msg_t));
          
          packet->id = TOS_NODE_ID;
          packet->message_type = 0;
          packet->topic = 0;
          packet->payload = call Random.rand32() % 101;
          
          generate_send(i, message);
        }
      }
    } else {
      dbgerror("Radio", "Radio failed to start, retrying...\n");
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    /* Fill it ... */
  }
  
  event void Timer0.fired() {
  }
  
  event void Timer1.fired() {
  }
  
  event void Timer2.fired() {
  }

  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
	/*
	* Parse the receive packet.
	* Implement all the functionalities
	* Perform the packet send using the generate_send function if needed
	* Implement the LED logic and print LED status on Debug
	*/
	radio_route_msg_t* message = (radio_route_msg_t*) payload;
	
	dbg("Radio_recv","Received a message with the following content:\n");
	dbg_clear("Data", "\tPacket type: %d\n", message->message_type);
    dbg_clear("Data", "\tPacket id: %d\n", message->id);
    dbg_clear("Data", "\tPacket topic: %d\n", message->topic);
    dbg_clear("Data", "\tPacket payload: %d\n", message->payload);
    
    return bufPtr;
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	/* This event is triggered when a message is sent 
	*  Check if the packet is sent 
	*/ 
      atomic{
        if (bufPtr == packetsPool[tail])
    	  tail = (tail + 1) % PACKET_POOL_SIZE;
    	
    	if (head != tail)
      	  post radioSendTask();
      }
  }
}




