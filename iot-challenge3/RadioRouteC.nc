
/*
*	IMPORTANT:
*	The code will be avaluated based on:
*		Code design  
*
*/


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
}
implementation {
  
  // Variables used by the generate_send function to store the message to send
  message_t queued_packet;
  uint16_t queue_addr;
  
  // other support variables
  uint16_t time_delays[7]={61,173,267,371,479,583,689}; // Time delay in milliseconds
  
  bool route_req_sent=FALSE;
  bool route_rep_sent=FALSE;
  
  bool locked = FALSE;
  
  bool openReq = FALSE;
  message_t packetDataToSend;
  uint16_t addressToSend;
  
  Route table[7];
  
  uint16_t personcode[8] = {1, 0, 6, 8, 7, 7, 4, 7};
  uint16_t ind = 0;
  

  /****** FUNCTIONS PROTOTYPES*******/
  
  bool destinationReachable (uint16_t address);
  void printPacketDebug(radio_route_msg_t* payload);
  bool generate_send (uint16_t address, message_t* packet, uint8_t type);
  bool actual_send (uint16_t address, message_t* packet);
  

  /****** FUNCTIONS *******/
  
  bool destinationReachable (uint16_t address){
  /*
  * Check if the destination is reachable
  */
    return (table[address - 1].next_hop != 0);
  }
  
  void printPacketDebug(radio_route_msg_t* payload){
  /*
  * Print packet's content in a structured way
  */
  	switch(payload->type){
      case DATA_MESSAGE:
        dbg_clear("radio_pack","\t Type: %u \n", payload->type);
        dbg_clear("radio_pack","\t Sender: %u \n", payload->sender);
        dbg_clear("radio_pack","\t Value: %u \n", payload->value);
        dbg_clear("radio_pack","\t Address: %u \n", payload->destination);
      break;
      case ROUTE_REQUEST:
        dbg_clear("radio_pack","\t Type: %u \n", payload->type);
        dbg_clear("radio_pack","\t Node requested: %u \n", payload->node_requested);
      break;
      case ROUTE_REPLY:
        dbg_clear("radio_pack","\t Type: %u \n", payload->type);
        dbg_clear("radio_pack","\t Sender: %u \n", payload->sender);
        dbg_clear("radio_pack","\t Node requested: %u \n", payload->node_requested);
        dbg_clear("radio_pack","\t Cost: %u \n", payload->cost);
      break;
    }
  }
  
  bool generate_send (uint16_t address, message_t* packet, uint8_t type){
  /*
  * Function to be used when performing the send after the receive message event.
  * It stores the packet and address into a global variable and starts the timer execution to schedule the actual send.
  * It allows the sending of only one message for each REQ and REP type.
  * @Input:
  *		address: packet destination address
  *		packet: full packet to be sent (Not only Payload)
  *		type: payload message type
  *
  * MANDATORY: DO NOT MODIFY THIS FUNCTION
  */
    if (call Timer0.isRunning()){
      return FALSE;
    }else{
      if (type == 1 && !route_req_sent ){
        route_req_sent = TRUE;
        call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
        queued_packet = *packet;
        queue_addr = address;
      }else if (type == 2 && !route_rep_sent){
          route_rep_sent = TRUE;
        call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
        queued_packet = *packet;
        queue_addr = address;
      }else if (type == 0){
        call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
        queued_packet = *packet;
        queue_addr = address;	
      }
    }
    return TRUE;
  }
  
  bool actual_send (uint16_t address, message_t* packet){
  /*
  * Implement here the logic to perform the actual send of the packet using the tinyOS interfaces
  */
    uint16_t next_hop;
    radio_route_msg_t* msg = (radio_route_msg_t*)call Packet.getPayload(packet, sizeof(radio_route_msg_t));  //we'll directly write on the pakcet to send
    if (msg == NULL) {
      return FALSE;
    }
  
    if (locked) {
      dbg("data", "Node %d found locked while sending data at time %s\n", TOS_NODE_ID, sim_time_string());
      return FALSE;
    }
    else {
      // routing protocol
      if (address != AM_BROADCAST_ADDR){  //not a broadcast message    
        if (!destinationReachable(address)){  //no route for requested address -> send route request message
          if (!route_req_sent){
            dbg("data","No route for actual address -> sending route request\n");
          
            packetDataToSend = *packet;  //save the packet that generated the request
            addressToSend = address;  //save the address that generated the request
            openReq = TRUE;
            
            dbg("data", "Delaying sending of packet with:\n");
            dbg_clear("radio_pack","\t Type: %u \n", msg->type);
            dbg_clear("radio_pack","\t Sender: %u \n", msg->sender);
            dbg_clear("radio_pack","\t Value: %u \n", msg->value);
            dbg_clear("radio_pack","\t Address: %u \n", addressToSend);
        
            msg->type = ROUTE_REQUEST;
            msg->node_requested = address;
                
            next_hop = AM_BROADCAST_ADDR; 	

            route_req_sent = TRUE;
          }
          else{
            dbg("data","No route for actual address but request already sent\n");
            return FALSE;
          }
        }
        else{
          dbg("data","Route found -> sending data packet\n");
          next_hop = table[address - 1].next_hop;
        }
      }
      else
        next_hop = address;  //if broadcast comunication incoming no need to filter its payload
    }
    
    if (call AMSend.send(next_hop, packet, sizeof(radio_route_msg_t)) == SUCCESS){
      locked = TRUE;
      
      dbg("radio_send", "Sending packet to next hop %d at time %s:\n", next_hop, sim_time_string());
      printPacketDebug(msg);
      
      return TRUE;
    }
    else
      return FALSE;
  }  
    
  
  /****** EVENT HANDLERS *******/
  
  event void Boot.booted() {
  
    // initialize routing table to empty state
    uint16_t i = 0;	
    for(; i < 7; i++){
      table[i].next_hop = 0;
      table[i].cost = 0;
    }
    
    dbg("boot","Application booted.\n");

    // initialize leds
    call Leds.led0Off();
    call Leds.led1Off();
    call Leds.led2Off();
    
    // print leds' initial status
    if (TOS_NODE_ID == 6)
      	dbg("leds_6", "Leds status: %u%u%u\n", call Leds.get() & 0x1, (call Leds.get() >> 1) & 0x1, (call Leds.get() >> 2) & 0x1);
    
    //start radio
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      dbg("radio","Radio on on node %d!\n", TOS_NODE_ID);

      // start Timer1 for Node 1 only
      if (TOS_NODE_ID == 1){
        dbg("timer","Starting Timer1 on node %d at %s\n", TOS_NODE_ID, sim_time_string());
        call Timer1.startOneShot( 5000 );
      }
    }
    else {
      dbgerror("radio", "Radio failed to start, retrying...\n");
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    dbg("boot", "Radio stopped!\n");
  }
  
  event void Timer0.fired() {
  /*
  * Timer triggered to perform the send.
  * MANDATORY: DO NOT MODIFY THIS FUNCTION
  */
    actual_send (queue_addr, &queued_packet);
  }
  
  event void Timer1.fired() {
  /*
  * Implement here the logic to trigger the Node 1 to send the first REQ packet
  */
    radio_route_msg_t* msg = (radio_route_msg_t*)call Packet.getPayload(&queued_packet, sizeof(radio_route_msg_t));
    if (msg == NULL) {
      return;
    }
    
    msg->type = DATA_MESSAGE;
    msg->sender = TOS_NODE_ID;
    msg->destination = 7;
    msg->value = 5;
    
    queue_addr = msg->destination;

    dbg("data", "Node %d sending first data packet at time %s\n", TOS_NODE_ID, sim_time_string());
    generate_send (queue_addr, &queued_packet, DATA_MESSAGE);
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
  /*
  * Parse the received packet.
  * Implement all the functionalities.
  * Perform the packet send using the generate_send function if needed.
  * Implement the LED logic and print LED status on debug.
  */
    radio_route_msg_t* sdm = (radio_route_msg_t*)call Packet.getPayload(bufPtr, sizeof(radio_route_msg_t));
    
    if (len != sizeof(radio_route_msg_t) || sdm == NULL) {
      return bufPtr;
    }
    else {
      radio_route_msg_t* rcm = (radio_route_msg_t*)payload;
      
      //dbg("radio_rec", "Received packet at time %s:\n", sim_time_string());
      //printPacketDebug(rcm);
      
      // handle routing protocol
      switch (rcm->type){
        case ROUTE_REQUEST:
        //Broadcast it if the ROUTE_REQ is a new one (i.e. requesting for a node not in my routing table and not me)
          if (!destinationReachable(rcm->node_requested) && rcm->node_requested != TOS_NODE_ID){
            generate_send(AM_BROADCAST_ADDR, bufPtr, ROUTE_REQUEST);
          }
        
          //If I am the node requested, I reply in broadcast with a ROUTE_REPLY, setting the ROUTE_REPLY cost to 1
          else if(rcm->node_requested == TOS_NODE_ID){
            sdm->type = ROUTE_REPLY;
            sdm->sender = TOS_NODE_ID;
            sdm->node_requested = TOS_NODE_ID;
            sdm->cost = 1;
            generate_send(AM_BROADCAST_ADDR, bufPtr, ROUTE_REPLY);
          }

          //If the node requested is in my routing table, I reply in broadcast with a ROUTE_REPLY, setting the ROUT_REPLY cost to the cost in my routing table + 1
          else if(destinationReachable(rcm->node_requested)){
            sdm->type = ROUTE_REPLY;
            sdm->sender = TOS_NODE_ID;
            sdm->node_requested = rcm->node_requested; //not useful, already set
            sdm->cost = table[rcm->node_requested - 1].cost + 1;
            generate_send(AM_BROADCAST_ADDR, bufPtr, ROUTE_REPLY);
          }
        break;

        case ROUTE_REPLY:
          // If I am the requested node in the reply
          if(rcm->node_requested == TOS_NODE_ID){
            //do nothing
          }

          //If my table does not have entry or if the new cost is lower than my current cost: I update my routing table ,
          //I forward the ROUTE_REPLY in broadcast by incrementing its cost by 1
          else if(!destinationReachable(rcm->node_requested) || rcm->cost < table[rcm->node_requested - 1].cost){
            table[rcm->node_requested - 1].next_hop = rcm->sender;
            table[rcm->node_requested - 1].cost = rcm->cost;
            
          //Check if now can send data message
          if(openReq==TRUE && destinationReachable(addressToSend)){
            dbg("data", "Node %d can finally send data %s\n", TOS_NODE_ID, sim_time_string());
            openReq = FALSE;
            generate_send(addressToSend, &packetDataToSend, DATA_MESSAGE);
          }
          else{
            sdm->sender = TOS_NODE_ID;
            sdm->cost = rcm->cost + 1;
            generate_send(AM_BROADCAST_ADDR, bufPtr, ROUTE_REPLY);
          }
            
          }
          
        break;

        case DATA_MESSAGE:
          if(rcm->destination != TOS_NODE_ID)
            generate_send(rcm->destination, bufPtr, DATA_MESSAGE);  //If i am not the destination: forward to next hop -> actual_send will take into account for this
          else
            dbg("data", "Data message received from node %d with value %d\n",rcm->sender, rcm->value);  //If I am the destination: print the message
        break;
      }
      
      
      // Leds logic
      switch(personcode[ind] % 3){
        case 0:
          call Leds.led0Toggle();
        break;
        case 1:
          call Leds.led1Toggle();
        break;
        case 2:
          call Leds.led2Toggle();
        break;
      }

      // print leds' status
      dbg("leds", "Leds status: %u%u%u\n", call Leds.get() & 0x1, (call Leds.get() >> 1) & 0x1, (call Leds.get() >> 2) & 0x1);
      if (TOS_NODE_ID == 6)
      	dbg("leds_6", "Leds status: %u%u%u\n", call Leds.get() & 0x1, (call Leds.get() >> 1) & 0x1, (call Leds.get() >> 2) & 0x1);
      
      
      // round-robin increment of index
      ind++;
      if (ind >= 8)
        ind = 0;
      
      return bufPtr;
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
  /* This event is triggered when a message is sent 
  *  Check if the packet is sent 
  */ 
    if (&queued_packet == bufPtr) 
      locked = FALSE;
  }
}
