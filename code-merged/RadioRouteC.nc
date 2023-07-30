
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
    interface Packet;
    interface Random;
  }
}
implementation {
  
  
  // Variables
  
  message_t* packetsPool[PACKET_POOL_SIZE];
  uint16_t addressesPool[PACKET_POOL_SIZE];
  uint8_t head = 0;
  uint8_t tail = 0;
  // Variables for retransmission
  uint16_t requestAddress = 0;
  message_t* request;
  
  
  // Functions prototypes
  
  void generate_send (uint16_t address, uint16_t message_type, uint16_t id, uint16_t topic, uint16_t payload, bool retFlag);
  void handleRetransmission(uint16_t address, message_t* message);

  void printPacketDebug(radio_route_msg_t* payload);

  bool searchID(Node* list, uint8_t node_id);
  Node* addNode(Node* list, uint8_t node_id);
  void printList(Node* list);

  void handleCONNECT(message_t* message);
  void handleCONNACK(message_t* message);
  void handleSUB(message_t* message);
  void handleSUBACK(message_t* message);
  void handlePUBLISH(message_t* message);
  
  // Tasks prototypes
  
  task void radioSendTask();
  
  
  // Functions
  
  void generate_send (uint16_t address, uint16_t message_type, uint16_t id, uint16_t topic, uint16_t payload, bool retFlag){
  	message_t* message = (message_t*) malloc(sizeof(message_t));
    radio_route_msg_t* packet = (radio_route_msg_t*)call Packet.getPayload(message, sizeof(radio_route_msg_t));
  
    packet->message_type = message_type;
    packet->id = id;
    packet->topic = topic;
    packet->payload = payload;
  	
  	atomic{
  	  packetsPool[head] = message;
  	  addressesPool[head] = address;
 	    head = (head + 1) % PACKET_POOL_SIZE;
  	}
  	
    if(retFlag)
      handleRetransmission(address,message);
  	post radioSendTask();

  } 
  
  void handleRetransmission(uint16_t address, message_t* message){
  /*
  * Handle retransmission of the specified packet
  */
    request = (message_t*) malloc(sizeof(message_t));
    memcpy(request, message, sizeof(message_t));
    requestAddress = address;
    call Timer0.startOneShot(ACK_TIMEOUT);
  }

  void handleCONNECT(message_t* message){
    packet = (radio_route_msg_t*)call Packet.getPayload(message, sizeof(radio_route_msg_t));
    connections = addNode(connections, packet->id);
    dbg("Data", "Printing list of active connections:\n");
    printList(connections);
    packet->message_type = CONNACK;
    generate_send(packet->id, message);
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
  
	  if (err == SUCCESS){
      dbg("Radio","Radio on.\n");
      if (TOS_NODE_ID == 1){
        for(i = 2; i <= 9; i++)
          generate_send(i, 0, TOS_NODE_ID, 2, 3);
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

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
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
      if (bufPtr == packetsPool[tail]){
        free(packetsPool[tail]);
        tail = (tail + 1) % PACKET_POOL_SIZE;
      }
    	
    	if (head != tail)
      	post radioSendTask();
    }
  }
}




