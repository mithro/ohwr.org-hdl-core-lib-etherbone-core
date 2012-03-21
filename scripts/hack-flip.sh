#! /bin/bash
# Goal: read the current timestamps off two devices
# Add 5 seconds to each and set off a 100ms pulse

dev1="$1"
dev2="$2"
wait_s="5"
pulse_ns="100000000"

schedule () {
  dev="$1"
  delay_s="$2"
  delay_ns="$3"
  
  echo -n "  $dev: "
  
  # Read the timestamp
  UTC0=`eb-read $dev1 0x180408/4`
  UTC1=`eb-read $dev1 0x18040C/4`
  CYC=`eb-read $dev1 0x180410/4`
  
  # Compute the deadline
  NS=$((CYC*8 + delay_ns))
  S_OVER=$((NS/1000000000))
  UTC=$((UTC0*256 + UTC1 + delay_s + S_OVER))
  NS=$((NS-S_OVER*1000000000))
  CYC=$((NS/8))

  echo -n `date +"%Y-%M-%d %H:%M:%S" -d @$UTC`
  printf ".%09d\n" $NS
  
  eb-write $dev 0x140010/4 0 # utchi
  eb-write $dev 0x140014/4 `printf 0x%x $UTC` # utclo
  eb-write $dev 0x140018/4 `printf 0x%x $CYC` # cycle
  eb-write $dev 0x14001C/4 0xffffffff # toggle all LEDs
  eb-write $dev 0x140000/4 0 # enqueue command
}

# Step 1: detect and configure device TLUs
echo "Configuring TLUs to latch pulse"

# Flush FIFO
if ! eb-write $dev1 0x180004/4 0xf; then echo "$dev1 TLU not found"; exit 1; fi
if ! eb-write $dev2 0x180004/4 0xf; then echo "$dev2 TLU not found"; exit 1; fi
# Enable capture
eb-write -p $dev1 0x18000C/4 0xf
eb-write -p $dev2 0x18000C/4 0xf

echo -n "Waiting for pulse... "
while true; do
  dev1stat=0x`eb-read -p $dev1 0x180404/4`
  dev2stat=0x`eb-read -p $dev2 0x180404/4`
  let dev1rdy=dev1stat*1
  let dev2rdy=dev2stat*1
  if [ $dev1rdy -gt 0 -a $dev2rdy -gt 0 ]; then break; fi
  sleep 1
done

echo "done"
eb-write -p $dev1 0x18000C/4 0x0
eb-write -p $dev2 0x18000C/4 0x0

echo "Scheduling events:"
schedule $dev1 $wait_s 0
schedule $dev1 $wait_s $pulse_ns
schedule $dev2 $wait_s 0
schedule $dev2 $wait_s $pulse_ns
