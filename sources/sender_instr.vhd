----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/11/2025 06:41:40 PM
-- Design Name: 
-- Module Name: sender_instr - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sender_instr is
    Port ( 
        horloge   : in std_logic;
        reset     : in std_logic; 
        
        enable    : in std_logic;                 
        instr     : in std_logic_vector(7 downto 0); 
        fifo_full : in std_logic;                 
        
        wr_en     : out std_logic;                
        busy      : out std_logic;              
        adr_AT    : out std_logic_vector(7 downto 0)
    );
end entity;

architecture Behavioral of sender_instr is

    type rom_8b is array(0 to 255) of std_logic_vector(7 downto 0);
    type rom_4b is array(0 to 15) of natural range 0 to 255;
    
    -- Signaux internes
    signal ptr_actuel : natural range 0 to 255 := 0;
    signal ptr_fin    : natural range 0 to 255 := 0;
    signal octet      : std_logic_vector (7 downto 0);
    
    -- Machine à états
    type state_type is (IDLE, LOAD_PTR, PTR_LOADED, READ_OCTET, WAIT_FIFO, SEND_OCTET, WAIT_NEXT_OCTET, NEXT_OCTET);
    signal etat_present : state_type := IDLE;
    signal etat_futur : state_type := IDLE;
    

constant ROM_AT_instr : rom_8b := (
        -- 1. AT
        0  => x"41", 1  => x"54", 2  => x"0D", 3 => x"0A",

        -- 2. AT+RST
        4  => x"41", 5  => x"54", 6  => x"2B", 7  => x"52", 8  => x"53", 9  => x"54", 10 => x"0D", 11 => x"0A",

        -- 3. AT+CWMODE=2
        12 => x"41",13 => x"54",14 => x"2B",15 => x"43",16 => x"57",17 => x"4D",
        18 => x"4F",19 => x"44",20 => x"45",21 => x"3D",22 => x"32",23 => x"0D",24 => x"0A",

        -- 4. AT+CWSAP="Nexys_AP","12345678",5,3
        25 => x"41",26 => x"54",27 => x"2B",28 => x"43",29 => x"57",30 => x"53",31 => x"41",32 => x"50",33 => x"3D",
        34 => x"22",35 => x"4E",36 => x"65",37 => x"78",38 => x"79",39 => x"73",40 => x"5F",41 => x"41",42 => x"50",43 => x"22",
        44 => x"2C",45 => x"22",46 => x"31",47 => x"32",48 => x"33",49 => x"34",50 => x"35",51 => x"36",52 => x"37",53 => x"38",54 => x"22",
        55 => x"2C",56 => x"35",57 => x"2C",58 => x"33",59 => x"0D",60 => x"0A",

        -- 5. AT+CIPAP="10.0.0.1","10.0.0.1","255.255.255.0"
        61 => x"41",62 => x"54",63 => x"2B",64 => x"43",65 => x"49",66 => x"50",67 => x"41",68 => x"50",69 => x"3D",
        70 => x"22",71 => x"31",72 => x"30",73 => x"2E",74 => x"30",75 => x"2E",76 => x"30",77 => x"2E",78 => x"31",79 => x"22",
        80 => x"2C",81 => x"22",82 => x"31",83 => x"30",84 => x"2E",85 => x"30",86 => x"2E",87 => x"30",88 => x"2E",89 => x"31",90 => x"22",
        91 => x"2C",92 => x"22",93 => x"32",94 => x"35",95 => x"35",96 => x"2E",97 => x"32",98 => x"35",99 => x"35",100 => x"2E",101 => x"32",
        102 => x"35",103 => x"35",104 => x"2E",105 => x"30",106 => x"22",107 => x"0D",108 => x"0A",

        -- 6. AT+CIPMUX=1
        109 => x"41",110 => x"54",111 => x"2B",112 => x"43",113 => x"49",114 => x"50",115 => x"4D",116 => x"55",117 => x"58",118 => x"3D",
        119 => x"31",120 => x"0D",121 => x"0A",

        -- 7. AT+CIPSERVER=1,8080
        122 => x"41",123 => x"54",124 => x"2B",125 => x"43",126 => x"49",127 => x"50",128 => x"53",129 => x"45",130 => x"52",131 => x"56",
        132 => x"45",133 => x"52",134 => x"3D",135 => x"31",136 => x"2C",137 => x"38",138 => x"30",139 => x"38",140 => x"30",141 => x"0D",
        142 => x"0A",
        
        others => x"00"
    );
    
        constant ROM_cmd : rom_4b := (
        -- 1. AT
        0  => 0, 1  => 3, 

        -- 2. AT+RST
        2  => 4, 3  => 11,
        -- 3. AT+CWMODE=2
        4 => 12,5 => 24,
        
        -- 4. AT+CWSAP="Nexys_AP","12345678",5,3
        6 => 25,7 => 60,
        
        -- 5. AT+CIPAP="10.0.0.1","10.0.0.1","255.255.255.0"
        8 => 61,9 => 108,
        -- 6. AT+CIPMUX=1
        10 => 109,11 => 121,
        -- 7. AT+CIPSERVER=1,8080
        12 => 122 ,13 => 142,
        others => 0
    );




begin

    calcul_etat_futur: process(etat_present, enable, fifo_full, ptr_actuel, ptr_fin)
    begin
        case etat_present is
            when IDLE => 
                if enable = '1' then
                    etat_futur <= LOAD_PTR;
                else
                    etat_futur <= IDLE;
                end if;
                
            when LOAD_PTR => 
                etat_futur <= PTR_LOADED;
                
            when PTR_LOADED =>
                etat_futur <= READ_OCTET;
                
            when READ_OCTET =>
                if ptr_actuel > ptr_fin then
                    etat_futur <= IDLE;
                else
                    etat_futur <= WAIT_FIFO;
                end if;
                
            when WAIT_FIFO => 
                if fifo_full = '0' then
                    etat_futur <= SEND_OCTET;
                else
                    etat_futur <= WAIT_FIFO;
                end if;
                
           when SEND_OCTET =>
            etat_futur <= WAIT_NEXT_OCTET;
            
          when WAIT_NEXT_OCTET =>
            etat_futur <= NEXT_OCTET;
           
           when NEXT_OCTET =>
            etat_futur <= READ_OCTET;
          
        end case;
    end process;
    
    
    registre: process(horloge)
    begin
        if rising_edge(horloge) then 
            if reset = '1' then
                etat_present <= IDLE;
            else
                etat_present <= etat_futur;
                
                case etat_present is
                    when IDLE => 
                        ptr_actuel <= 0;
                        ptr_fin <= 1;
                    when LOAD_PTR => 
                        ptr_actuel <= ROM_cmd(2 * to_integer(unsigned(instr)));
                        ptr_fin <= ROM_cmd(2 * to_integer(unsigned(instr)) + 1);
                    when READ_OCTET =>
                        octet <= ROM_AT_instr(ptr_actuel);
                    when NEXT_OCTET =>
                        ptr_actuel <= ptr_actuel + 1;
                    when others => 
                        ptr_actuel <= ptr_actuel;
                    
                 end case;
                        
                
            end if;
        end if;
    end process;
    
    
    calcul_sortie: process(etat_present, octet)
    begin
        case etat_present is
            when IDLE =>
                wr_en <= '0';   
                busy <=  '0';
                adr_AT <= octet;
                
            when LOAD_PTR =>
                wr_en <= '0';   
                busy <=  '1';
                adr_AT <= octet;
                
            when PTR_LOADED =>
                wr_en <= '0';   
                busy <=  '1';
                adr_AT <= octet;
                
            when READ_OCTET =>
                wr_en <= '0';   
                busy <=  '1';
                adr_AT <= octet;
                
            when WAIT_FIFO =>
                wr_en <= '0';   
                busy <=  '1';
                adr_AT <= octet;
                
            when SEND_OCTET =>
                wr_en <= '1';   
                busy <=  '1';
                adr_AT <= octet;
                
            when WAIT_NEXT_OCTET =>
                wr_en <= '0';   
                busy <=  '1';
                adr_AT <= octet;
                
            when NEXT_OCTET =>
                wr_en <= '0';   
                busy <=  '1';
                adr_AT <= octet;
                
           
        end case;
    end process;
    
    
        
end Behavioral;
