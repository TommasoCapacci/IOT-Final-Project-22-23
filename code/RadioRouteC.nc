#include "Timer.h"
#include "RadioRoute.h"


module RadioRouteC @safe() {
  uses {
  
    /****** INTERFACES *****/
    interface Boot;
    interface Receive;
    interface AMSend;
    interface SplitControl as AMControl;
    interface Leds;
    interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;
    interface Packet;
    
  }
} implementation {
  

  /****** VARIABLES *******/

  message_t queued_packet;
  bool locked = FALSE;

  uint16_t requestAddress = 0;
  radio_route_msg_t* request = NULL;

  Node* connections = NULL;
  Node* subscriptions[3] = {NULL, NULL, NULL};
  

  /****** FUNCTIONS PROTOTYPES*******/
  
  void printPacketDebug(radio_route_msg_t* packet);

  Node* addNode(Node* list, uint8_t id);
  bool searchNode(Node* list, uint8_t id);

  void handleRetransmission(uint16_t address, radio_route_msg_t* packet)
  void handleCONNECT(radio_route_msg_t* packet);
  void handleCONNACK(radio_route_msg_t* packet);
  void handleSUB(radio_route_msg_t* packet);
  void handleSUBACK(radio_route_msg_t* packet);
  void handlePUBLISH(radio_route_msg_t* packet);

  bool generate_send(uint16_t address, radio_route_msg_t* packet);
  

  /****** FUNCTIONS *******/
  
  void printPacketDebug(radio_route_msg_t* packet){
  /*
  * Print packet's content in a structured way
  */
    dbg("radio_pack", "Packet type: %d\n", packet->message_type);
    dbg("radio_pack", "Packet id: %d\n", packet->id);
    dbg("radio_pack", "Packet topic: %d\n", packet->topic);
    dbg("radio_pack", "Packet payload: %s\n", packet->payload);
  }

  Node* addNode(Node* list, uint16_t id){
  /*
  * Add a node to the head of the specified list
  */
    Node* newNode = (Node*)malloc(sizeof(Node));
    newNode->id = id;
    newNode->next = list;
    return newNode;
  }

  bool searchNode(Node* list, uint8_t id){
  /*
  * Search a node inside the specified list
  */
    Node* current = list;
    while (current != NULL){
      if (current->id == id)
        return TRUE;
      current = current->next;
    }
    return FALSE;
  }

  void handleRetransmission(uint16_t address, radio_route_msg_t* packet){
  /*
  * Handle retransmission of the specified packet
  */
    request = packet;
    requestAddress = address;
    call Timer0.startOneShot(ACK_TIMEOUT);
  }

  void handleCONNECT(radio_route_msg_t* packet){
    connections = addNode(connections, packet->id);
    packet->message_type = CONNACK;
    generate_send(packet->id, packet);
  }

  void handleCONNACK(radio_route_msg_t* packet){
    if (openRequest && request->message_type == CONNECT)
      call Timer0.stop();

    // generate and send random subscription request (even in broadcast)
      uint8_t topic = call Random.rand32() % 3;
      packet->id = TOS_NODE_ID;
      packet->message_type = SUB;
      packet->topic = topic;
      generate_send(AM_BROADCAST_ADDR, packet);
      handleRetransmission(AM_BROADCAST_ADDR, packet);
  }

  void handleSUB(radio_route_msg_t* packet){
  }

  void handleSUBACK(radio_route_msg_t* packet){
  }

  void handlePUBLISH(radio_route_msg_t* packet){
  }  

  bool generate_send(uint16_t address, message_t* packet){
  /*
  * Send the specified packet to the specified address
  */
    if (call AMSend.send(address, packet, sizeof(radio_route_msg_t)) == SUCCESS){
      locked = TRUE;
      dbg("radio_send", "Sending packet at time %s:\n", sim_time_string());
      printPacketDebug(packet);
      return TRUE;
    }
    return FALSE;
  }
    
  
  /****** EVENT HANDLERS *******/
  
  event void Boot.booted() {
    dbg("boot","Application booted.\n");
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS){
      dbg("radio","Radio on on node %d!\n", TOS_NODE_ID);
      if (TOS_NODE_ID != 1){
        // send connect message to node 1 (even in broadcast, should be more realistic)
        radio_route_msg_t* sdm = (radio_route_msg_t*)call Packet.getPayload(queued_packet, sizeof(radio_route_msg_t));
        if (len != sizeof(radio_route_msg_t) || sdm == NULL) {
          return bufPtr;
        }

        sdm->id = TOS_NODE_ID;
        sdm->message_type = CONNECT;
        generate_send(AM_BROADCAST_ADDR, queued_packet);
        handleRetransmission(AM_BROADCAST_ADDR, queued_packet);
      }
    } else {
      dbgerror("radio", "Radio failed to start, retrying...\n");
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    dbg("boot", "Radio stopped!\n");
  }
  
  event void Timer0.fired() {
  /*
  * Use this timer to handle retransmissions
  */
    generate_send(requestAddress, request);
    call Timer0.startOneShot(ACK_TIMEOUT);
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
  /*
  * Parse the received packet and prepare the relative response
  */
    queued_packet = *bufPtr;
    radio_route_msg_t* rcm = (radio_route_msg_t*)payload;
    
    //dbg("radio_rec", "Received packet at time %s:\n", sim_time_string());
    //printPacketDebug(rcm);
    
    switch (rcm->message_type){
      case CONNECT:
        handleCONNECT(rcm);
      break;
      case CONNACK:
        handleCONNACK(rcm);
      break;
      case SUB:
        handleSUB(rcm);
      break;
      case SUBACK:
        handleSUBACK(rcm);
      break;
      case PUBLISH:
        handlePUBLISH(rcm);
      break;
    }
  }
  
  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
  /* 
  * Check if the right packet has been sent 
  */ 
    if (&queued_packet == bufPtr) 
      locked = FALSE;
  }
}
