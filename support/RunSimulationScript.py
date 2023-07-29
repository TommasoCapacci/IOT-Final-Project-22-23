import sys
import os 
import time 

from TOSSIM import * 

print("\n********************************************")
print("*                                          *")
print("*             TOSSIM Script                *")
print("*                                          *")
print("********************************************\n")

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

simulation_outfile = "TOSSIM_LOG.txt"
print("Saving simulation's output to " + simulation_outfile)
out = open(simulation_outfile, ("w"))

# DEBUG CHANELS
channels = ["Boot", "Timer", "Radio", "Radio_send", "Radio_recv", "Data"]
for c in channels:
	print("Activate debug message on channel " + c)
	t.addChannel(c, out) 


# NODES CREATION
num_nodes = 9 
for i in range(1, num_nodes + 1):
    print("Creating node " + str(i) + "...")
    node1 = t.getNode(i) 
    time = 0 
    node1.bootAtTime(time) 
    print(">>>Will boot at time " + str(time/t.ticksPerSecond()) + "[sec]")


# RADIO CHANNELS CREATION
print("Creating radio channels...")
f = open(topofile,("r"))
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print(">>>Setting radio channel from node " + s[0] + " to node " + s[1] + " with gain " + s[2] + " dBm")
    radio.add(int(s[0]), int(s[1]), float(s[2]))


# NOISE MODELS CREATION
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
