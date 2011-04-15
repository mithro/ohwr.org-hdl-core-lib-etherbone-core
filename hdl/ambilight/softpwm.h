//! Pin mappings
   // maximum number of PWM channels
#define LEDMAX      	4    // maximum number of LEDs
#define COLMAX    		3
#define CHMAX       	LEDMAX * COLMAX 

#define T_DEFAULT		03
#define V_DEFAULT		255
#define H_DEFAULT_DIFF	64
#define COLOR_SHIFT		1
#define COLOR_CONST		0

//Zyxel RC
#define RC_INC 			24
#define RC_DEC 			16
#define RC_PUP 			75
#define RC_PDOWN 		28
#define RC_OFF 			67
#define RC_UP 			20
#define RC_DOWN 		22
#define RC_LEFT 		29
#define RC_OK 			21

#define IRC_T_INC		RC_PUP	//farben rotieren langsamer 
#define IRC_T_DEC		RC_PDOWN	//farben rotieren schneller
#define IRC_SHFT		RC_OK	//farben rotieren oder constant
#define IRC_MULTI		3	//4 verschiedene Farben
#define IRC_SINGLE		4	//Nur 1 Farbe
#define IRC_H_INC		5	//H erhöhen
#define IRC_H_DEC		6	//H erniedrigen
#define IRC_V_INC		RC_INC	//V erhöhen
#define IRC_V_DEC		RC_DEC	//V erhöhen



		
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
