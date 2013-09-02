dev=$1

eb-write -p udp/$dev 0x300000/4 0xDEADBEE0 #2
#eb-write -p udp/$dev 0x380000/4 0xDEADBEE1 #3
#eb-write -p udp/$dev 0x380004/4 0xDEADBEEA #3
#eb-write -p udp/$dev 0x380008/4 0xDEADBEEB #3
#eb-write -p udp/$dev 0x300000/4 0xDEADBEE2 #4
#eb-write -p udp/$dev 0x380000/4 0xDEADBEE3 #5
#eb-write -p udp/$dev 0x380004/4 0xDEADBEE4 #5
#eb-write -p udp/$dev 0x380008/4 0xDEADBEE5 #5
eb-write -p udp/$dev 0x380000/4 0xDEADBEE6 #5




