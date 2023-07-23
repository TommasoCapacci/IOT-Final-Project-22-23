import sys
import os 
import time 

from TOSSIM import * 

print("********************************************")
print("*                                          *")
print("*             TOSSIM Script                *")
print("*                                          *")
print("********************************************")

t = Tossim([]) 

topofile="topology.txt"
modelfile="meyer-heavy.txt"

print("Initializing mac....")
mac = t.mac() 
print("Initializing radio channels....")
radio = t.radio() 
print("    using topology file: " + topofile)
print("    using noise file: " + modelfile)
print("Initializing simulator....")
t.init() 

simulation_outfile = os.path.join("..", "TOSSIM_LOG.txt")
print("Saving sensors simulation output to " + simulation_outfile)
out = open(simulation_outfile, ("w"))

#Add debug channel
print("Activate debug message on channel boot")
t.addChannel("boot",out) 
print("Activate debug message on channel timer")
t.addChannel("timer",out) 
print("Activate debug message on channel leds")
t.addChannel("leds",out)
print("Activate debug message on channel radio")
t.addChannel("radio",out) 
print("Activate debug message on channel radio_send")
t.addChannel("radio_send",out) 
print("Activate debug message on channel radio_rec")
t.addChannel("radio_rec",out) 
print("Activate debug message on channel radio_pack")
t.addChannel("radio_pack",out) 
print("Activate debug message on channel data")
t.addChannel("data",out)

#print("Activate debug message channel for node 6's leds")
#t.addChannel("leds_6",out)


# NODES CREATION
num_nodes = 7  # CHANGE THIS FOR DIFFERENT NUMBERS OF NODES
for i in range(1, num_nodes + 1):
    print("Creating node " + str(i) + "...")
    node1 = t.getNode(i) 
    time = 0 
    node1.bootAtTime(time) 
    print(">>>Will boot at time " + str(time/t.ticksPerSecond()) + "[sec]")


# KEEP LIKE THIS
print("Creating radio channels...")
f = open(topofile,("r"))
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print(">>>Setting radio channel from node " + s[0] + " to node " + s[1] + " with gain " + s[2] + " dBm")
    radio.add(int(s[0]), int(s[1]), float(s[2]))

print("Initializing Closest Pattern Matching (CPM)...")
noise = open(modelfile,("r"))
lines = noise.readlines()
compl = 0 
mid_compl = 0 

print("    using noise model data file: " + modelfile)
print("Loading: ")
for line in lines:
    s = line.strip()
    if s !=("") and ( compl < 10000 ):
        val = int(s)
        mid_compl = mid_compl + 1 
        if ( mid_compl > 5000 ):
            compl = compl + mid_compl 
            mid_compl = 0 
            sys.stdout.write ("#")
            sys.stdout.flush()
        for i in range(1, num_nodes + 1):  
            t.getNode(i).addNoiseTraceReading(val)
print("Done!")

for i in range(1, num_nodes + 1):
    print(">>>Creating noise model for node " + str(i)) 
    t.getNode(i).createNoiseModel()


# START SIMULATION
print("Start simulation with TOSSIM! \n\n\n")

num_events = 10000
for i in range(0, num_events):
	t.runNextEvent()

# END SIMULATION	
print("\n\n\nSimulation finished!")
