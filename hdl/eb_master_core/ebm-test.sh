dev=$1


eb-write udp/$dev 0x20000C/4 0x080030E3	#my mac
eb-write udp/$dev 0x200010/4 0xB05A0000
eb-write udp/$dev 0x200014/4 0xC0A8BFFE #my ip
eb-write udp/$dev 0x200018/4 0x0000EBD1 #my port
eb-write udp/$dev 0x20001C/4 0xBC305BE2 #his mac
eb-write udp/$dev 0x200020/4 0xB0880000 
eb-write udp/$dev 0x200024/4 0xC0A8BF1F #his ip
#eb-write udp/$dev 0x200024/4 0xC0A8BFFF #his ip / broadcast

eb-write udp/$dev 0x200028/4 0x0000EBD0 #his port
eb-write udp/$dev 0x20002C/4 0x00000050 #udp packet length 
eb-write udp/$dev 0x200030/4 0x00000000 #adr hi bits
eb-write udp/$dev 0x200034/4 0x00000010 #max ops
eb-write udp/$dev 0x200040/4 0x00000000 #EB options

./ebt.sh $dev

eb-write udp/$dev 0x200004/4 0x00000001 #flush


