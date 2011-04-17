//! Pin mappings
   // maximum number of PWM channels
#define TRUE			1
#define FALSE			0


#define LEDMAX      	4    // maximum number of LEDs
#define COLMAX    		3
#define CHMAX       	LEDMAX * COLMAX 

#define T_DEFAULT		03
#define V_DEFAULT		255
#define H_DEFAULT_DIFF	64

#define COLOR_SHIFT		1
#define COLOR_CONST		0

#define RC_INCDEC		4

#define CONFIG_SAVE		1
#define CONFIG_LOAD		0
#define CONFIG_RESET	255

#define TIMER2_SEC		31 //8M /( 1024 * 256 * 30,5 )  => 1s 


#define H_BLINK			85	//Gruen


//Zyxel RC
#define Z_RC_INC 		24
#define Z_RC_DEC 		16
#define Z_RC_PUP 		75
#define Z_RC_PDOWN 		28
#define Z_RC_OFF 		67
#define Z_RC_UP 		20
#define Z_RC_DOWN 		22
#define Z_RC_LEFT 		29
#define Z_RC_OK 		21
#define Z_RC_0			0
#define Z_RC_1			1
#define Z_RC_2			2
#define Z_RC_3			3
#define Z_RC_4			4
#define Z_RC_5			5
#define Z_RC_6			6
#define Z_RC_7			7
#define Z_RC_8			8
#define Z_RC_9			9



//commands
#define IRC_RESET		
#define IRC_T_INC		Z_RC_PUP	//farben rotieren langsamer 
#define IRC_T_DEC		Z_RC_PDOWN	//farben rotieren schneller
#define IRC_SHFT		Z_RC_OK	//farben rotieren oder constant
#define IRC_MULTI		255		//4 verschiedene Farben
#define IRC_SINGLE		254		//Nur 1 Farbe
#define IRC_H_INC		Z_RC_UP 	//H erhöhen
#define IRC_H_DEC		Z_RC_DOWN 	//H erniedrigen
#define IRC_V_INC		Z_RC_INC	//V erhöhen
#define IRC_V_DEC		Z_RC_DEC	//V erhöhen

//sleep timer
#define IRC_SLP_STOP	Z_RC_0	//sleep timer aus 
#define IRC_SLP_1		Z_RC_1	//10 min
#define IRC_SLP_2		Z_RC_2	//20 min
#define IRC_SLP_3		Z_RC_3	//30 min
#define IRC_SLP_4		Z_RC_4	//40 min
#define IRC_SLP_5		Z_RC_5	//50 min
#define IRC_SLP_6		Z_RC_6	//60 min
#define IRC_SLP_7		Z_RC_7	//70 min
#define IRC_SLP_8		Z_RC_8	//80 min
#define IRC_SLP_9		Z_RC_9	//90 min



		
//! Set bits corresponding to pin usage above
const uint8_t PORTB_MASK  = (1 << PD0)|(1 << PB1)|(1 << PB2)|(1 << PB3)|(1 << PB4);
const uint8_t PORTD_MASK  = (1 << PD0)|(1 << PD1)|(1 << PD2); //|(1 << PD3)|(1 << PD4)|(1 << PD5)|(1 << PD6);
				      //1		2		3		4		5		6		7		8
const char RGB[256] = {	0,		0,		0,		0,		0,		0,		0,		0,		
						0,		0,		0,		0,		0,		0,		0,		0,		
						0,		0,		0,		0,		0,		0,		0,		0,		
						0,		0,		0,		0,		0,		0,		0,		0,	//4	
						0,		0,		0,		0,		0,		0,		0,		0,		
						0,		0,		0,		0,		0,		0,		0,		0,		
						0,		0,		0,		0,		0,		0,		0,		0,		
						0,		0,		0,		0,		0,		0,		0,		0,	//8	
						0,		0,		0,		0,		0,		0,		0,		0,		
						0,		0,		0,		0,		0,		0,		0,		0,		
						0,		0,		0,		0,		0,		0,		4,		10,		
						16,		22,		28,		34,		40,		46,		52,		58,	//12	
						64,		70,		76,		82,		88,		94,		100,	106,		
						112,	118,	124,	129,	135,	141,	147,	153,		
						159,	165,	171,	177,	183,	189,	195,	201,		
						207,	213,	219,	225,	231,	237,	243,	249,//16		
						255,	255,	255,	255,	255,	255,	255,	255,		
						255,	255,	255,	255,	255,	255,	255,	255,
						255,	255,	255,	255,	255,	255,	255,	255,
						255,	255,	255,	255,	255,	255,	255,	255,//20		
						255,	255,	255,	255,	255,	255,	255,	255,
						255,	255,	255,	255,	255,	255,	255,	255,
						255,	255,	255,	255,	255,	255,	255,	255,
						255,	255,	255,	255,	255,	255,	255,	255,//24
						255,	255,	255,	255,	255,	255,	255,	255,
						255,	255,	255,	255,	255,	255,	255,	255,
						255,	255,	255,	255,	255,	255,	251,	245,
						239,	233,	227,	221,	215,	209,	203,	197,//28
						191,	185,	179,	173,	167,	161,	155,	149,
						143,	137,	131,	126,	120,	114,	108,	102,
						96,		90,		84,		78,		72,		66,		60,		54,
						48,		42,		36,		30,		24,		18,		12,		6};//32 * 8 = 256



#define LED_0R_CLR (pinlevelD &= ~(1 << PD0)) // LED0R map 0R   to PD2
#define LED_0G_CLR (pinlevelD &= ~(1 << PD1)) // LED0G map 0G   to PD3
#define LED_0B_CLR (pinlevelD &= ~(1 << PD2)) // LED0B map 0B   to PD4

#define LED_1R_CLR (pinlevelD &= ~(1 << PD5)) // LED1R map 1R   to PD5
#define LED_1G_CLR (pinlevelD &= ~(1 << PD6)) // LED1G map 1G   to PD6
#define LED_1B_CLR (pinlevelB &= ~(1 << PB0)) // LED1B map 1B   to PB0

#define LED_2R_CLR (pinlevelB &= ~(1 << PB1)) // LED2R map CH6  to PB1
#define LED_2G_CLR (pinlevelB &= ~(1 << PB2)) // LED2G map CH7  to PB2
#define LED_2B_CLR (pinlevelB &= ~(1 << PB3)) // LED2B map CH8  to PB3

#define LED_3R_CLR (pinlevelB &= ~(1 << PB4)) // LED3R map CH9  to PB4
#define LED_3G_CLR (pinlevelB &= ~(1 << PB5)) // LED3R map CH10 to PB5
#define LED_3B_CLR (pinlevelB &= ~(1 << PB6)) // LED3R map CH11 to PB6 





//! prototypes
void Init(void);
