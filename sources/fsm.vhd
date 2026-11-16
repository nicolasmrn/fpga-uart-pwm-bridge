----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/11/2025 04:57:30 PM
-- Design Name: 
-- Module Name: fsm - Behavioral
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

entity fsm is
    Port ( 
        horloge     : in std_logic;
        reset       : in std_logic;
        
        sender_busy : in std_logic;
        sig_ok      : in std_logic;
        sig_erreur  : in std_logic;
        sig_CNX     : in std_logic;
        sig_cmd     : in std_logic;
       
        
        cmd_AT_out  : out std_logic_vector (7 downto 0);
        sending     : out std_logic;
        cmd_led     : out std_logic_vector (1 downto 0);
        CE_PWMs     : out std_logic
    );
end fsm;

architecture Behavioral of fsm is

    type etat is (INIT_WAIT, INIT_SEND, 
                  ECHEC_WAIT, ECHEC_SEND,
                  RST_WAIT, RST_SEND, 
                  MODE_AP_WAIT, MODE_AP_SEND, 
                  CONF_AP_WAIT, CONF_AP_SEND,
                  SET_IP_WAIT, SET_IP_SEND, 
                  CONF_CNX_WAIT, CONF_CNX_SEND, 
                  CONF_SERV_WAIT, CONF_SERV_SEND, 
                  ATT_CNX, 
                  ATTENTE, 
                  EXECUTION);
    
    signal etat_present : etat := INIT_SEND;
    signal etat_futur : etat := INIT_SEND;
    constant led_echec : std_logic_vector (1 downto 0) := "00";
    constant led_attente_cnx : std_logic_vector (1 downto 0) := "01";
    constant led_config : std_logic_vector (1 downto 0) := "10";
    constant led_libre : std_logic_vector (1 downto 0) := "11";


begin

    calcul_etat_futur: process(etat_present, sig_ok, sig_erreur, sig_CNX, sig_cmd, sender_busy)
    begin
        case etat_present is
        
            when INIT_SEND => etat_futur <= INIT_WAIT;
            when INIT_WAIT => 
                if sig_ok = '1' then
                    if sender_busy = '0' then
                        etat_futur <= RST_SEND;
                    else
                        etat_futur <= INIT_WAIT;
                    end if;
                elsif sig_erreur = '1' then
                    etat_futur <= ECHEC_SEND;
                else
                    etat_futur <= INIT_WAIT;
                end if;
                
            when RST_SEND => etat_futur <= RST_WAIT;
                
            when RST_WAIT =>
                if (sig_ok = '1') and (sender_busy = '0') then
                    etat_futur <= MODE_AP_SEND;
                elsif sig_erreur = '1' then
                    etat_futur <= ECHEC_SEND;
                else
                    etat_futur <= RST_WAIT;
                end if;
                
            when MODE_AP_SEND => etat_futur <= MODE_AP_WAIT;
                
            when MODE_AP_WAIT =>
                if sig_ok = '1' and sender_busy = '0' then
                    etat_futur <= CONF_AP_SEND;
                elsif sig_erreur = '1' then
                    etat_futur <= RST_SEND;
                else
                    etat_futur <= MODE_AP_WAIT;
                end if;
                
            when CONF_AP_SEND => etat_futur <= CONF_AP_WAIT;
                
            when CONF_AP_WAIT =>
                if sig_ok = '1' and sender_busy = '0' then
                    etat_futur <= SET_IP_SEND;
                elsif sig_erreur = '1' then
                    etat_futur <= RST_SEND;
                else
                    etat_futur <= CONF_AP_WAIT;
                end if;
                
            when SET_IP_SEND => etat_futur <= SET_IP_WAIT;
                
            when SET_IP_WAIT =>
                if sig_ok = '1' and sender_busy = '0' then
                    etat_futur <= CONF_CNX_SEND;
                elsif sig_erreur = '1' then
                    etat_futur <= RST_SEND;
                else
                    etat_futur <= SET_IP_WAIT;
                end if;
             
            when CONF_CNX_SEND => etat_futur <= CONF_CNX_WAIT;
                
            when CONF_CNX_WAIT =>
                if sig_ok = '1' and sender_busy = '0' then
                    etat_futur <= CONF_SERV_SEND;
                elsif sig_erreur = '1' then
                    etat_futur <= RST_SEND;
                else
                    etat_futur <= CONF_CNX_WAIT;
                end if;
                
            when CONF_SERV_SEND => etat_futur <= CONF_SERV_WAIT;
                
            when CONF_SERV_WAIT => 
                if sig_ok = '1' and sender_busy = '0' then
                    etat_futur <= ATT_CNX;
                elsif sig_erreur = '1' then
                    etat_futur <= RST_SEND;
                else
                    etat_futur <= CONF_SERV_WAIT;
                end if;  
                 
            
            when ATT_CNX =>
                if sig_CNX = '1' then
                    etat_futur <= ATTENTE;
                else
                    etat_futur <= ATT_CNX;
                end if;
                
            when ATTENTE =>
                if sig_CNX = '1' then
                    if sig_cmd = '1' then
                        etat_futur <= EXECUTION;
                    else
                        etat_futur <= ATTENTE;
                    end if;
                else
                    etat_futur <= ATT_CNX;
                end if;
                
            when EXECUTION => 
                etat_futur <= ATTENTE;

                
            when ECHEC_SEND =>
                etat_futur <= ECHEC_WAIT;    
            
            when ECHEC_WAIT =>
                etat_futur <= ECHEC_WAIT;      
        end case;
     end process;
     
     
    registre: process(horloge)
    begin
        if rising_edge(horloge) then
            if reset = '1' then
                etat_present <= INIT_SEND;
            else
                etat_present <= etat_futur;
            end if;
        end if;
    end process;
    
    calcul_sortie: process(etat_present)
    begin
        case etat_present is
            
            when INIT_SEND =>
                cmd_led <= led_config;
                cmd_AT_out <= "00000000";
                sending <= '1';
                CE_PWMs <= '1';
            when INIT_WAIT =>
                cmd_led <= led_config;
                cmd_AT_out <= "00000000";
                sending <= '0';
                CE_PWMs <= '0';
                

                
            when RST_WAIT =>
                cmd_led <= led_config;
                cmd_AT_out <= "00000001";
                sending <= '0';
                CE_PWMs <= '1';
                
            when RST_SEND =>
                cmd_led <= led_config;
                cmd_AT_out <= "00000001";
                sending <= '1';
                CE_PWMs <= '0';
            
            when MODE_AP_WAIT =>
                cmd_led <= led_config;
                cmd_AT_out <= "00000010";
                sending <= '0';
                CE_PWMs <= '1';
            when MODE_AP_SEND =>
                cmd_led <= led_config;
                cmd_AT_out <= "00000010";
                sending <= '1';
                CE_PWMs <= '1';
             
            when CONF_AP_WAIT =>
                cmd_led <= led_config;
                cmd_AT_out <= "00000011";
                sending <= '0';
                CE_PWMs <= '0';
            when CONF_AP_SEND =>
                cmd_led <= led_config;
                cmd_AT_out <= "00000011";
                sending <= '1';
                CE_PWMs <= '1';
            
            when SET_IP_WAIT =>
                cmd_AT_out <= "00000100";
                cmd_led <= led_config;
                sending <= '0';
                CE_PWMs <= '0';
            when SET_IP_SEND =>
                cmd_AT_out <= "00000100";
                cmd_led <= led_config;
                sending <= '1';
                CE_PWMs <= '1';
                
             when CONF_CNX_WAIT =>
                cmd_AT_out <= "00000101";
                cmd_led <= led_config;
                sending <= '0';
                CE_PWMs <= '0';
             when CONF_CNX_SEND =>
                cmd_AT_out <= "00000101";
                cmd_led <= led_config;
                sending <= '1';
                CE_PWMs <= '1';
                
             when CONF_SERV_WAIT =>
                cmd_AT_out <= "00000110";
                cmd_led <= led_config;
                sending <= '0';
                CE_PWMs <= '0';
             when CONF_SERV_SEND =>
                cmd_AT_out <= "00000110";
                cmd_led <= led_config;
                sending <= '1';
                CE_PWMs <= '1';
                
             when ATT_CNX =>
                cmd_AT_out <= "00000000";
                cmd_led <= led_attente_cnx;
                sending <= '0';
                CE_PWMs <= '1';
                
             when ATTENTE =>
                cmd_AT_out <= "00000000";
                cmd_led <= led_libre;
                sending <= '0';
                CE_PWMs <= '0';
                
             when EXECUTION =>
                cmd_AT_out <= "00000000";
                cmd_led <= led_libre;
                sending <= '0';
                CE_PWMs <= '1';
                
             when ECHEC_SEND =>
                cmd_AT_out <= "00000000";
                cmd_led <= led_echec;
                sending <= '0';
                CE_PWMs <= '1';
                
             when ECHEC_WAIT =>
                cmd_AT_out <= "00000000";
                cmd_led <= led_echec;
                sending <= '0';
                CE_PWMs <= '0';
        end case;
        
    
    end process;
       


end Behavioral;
