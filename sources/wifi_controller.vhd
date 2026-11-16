
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/12/2025 03:29:55 PM
-- Design Name: 
-- Module Name: wifi_controller - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity wifi_controller is
    Port ( 
        HORLOGE :    in std_logic; 
        RESET   :    in std_logic;
        
        
        tx_terminal : out std_logic;
        
        tx_esp32    : out std_logic;
        rx_esp32    : in std_logic;
        
        LED_R       : out std_logic;
        LED_V       : out std_logic;
        LED_B       : out std_logic
        
    );
end wifi_controller;

architecture Behavioral of wifi_controller is



    component PWM is
        Port (
            IDATA: in std_logic_vector (7 downto 0);
            HORLOGE: in std_logic;
            CE: in std_logic;
            RAZ: in std_logic;
            ODATA: out std_logic;
            VAL_REG_O: out std_logic_vector (7 downto 0)
        );
    end component;
    
    
    component UART_recv is
        Port( clk    : in  STD_LOGIC;
              reset  : in  STD_LOGIC;
              rx     : in  STD_LOGIC;
              dat    : out STD_LOGIC_VECTOR (7 downto 0);
              dat_en : out STD_LOGIC);
    end component;
    
    component fsm is
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
    end component;
    
    component sender_instr is
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
    end component;
    
    component parser is
    Port (
        horloge     : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        
        rx_data     : in  STD_LOGIC_VECTOR(7 downto 0);
        rx_dv       : in  STD_LOGIC;
        
        -- Sorties
        sig_ok      : out STD_LOGIC;
        sig_erreur  : out STD_LOGIC;
        sig_CNX     : out STD_LOGIC;
        
        sig_cmd     : out STD_LOGIC;
        data_cmd    : out STD_LOGIC_VECTOR(23 downto 0)
    );
    end component;

    component uart_bridge2 is
    Generic (
        CLK_FREQ    : integer := 100_000_000; -- Fréquence de votre horloge (Basys3/Nexys4 = 100MHz)
        BAUD_RATE   : integer := 115_200      -- Vitesse de communication
    );
    Port ( 
        HORLOGE     : in  STD_LOGIC;
        RESET       : in  STD_LOGIC;
        
        -- Interface Terminal (PC via USB)
        tx_terminal : out STD_LOGIC;
        rx_terminal : in  STD_LOGIC;
        
        -- Interface ESP32 (Pmod ou fils volants)
        tx_esp32    : out STD_LOGIC;
        rx_esp32    : in  STD_LOGIC
    );
    end component;
    
    component transmetteur is
    generic(
        CLK_FREQ  : integer := 100_000_000;
        BAUD_RATE : integer := 115_200
    );
    port(
        horloge     : in  std_logic;
        reset       : in  std_logic;
        data_in     : in  std_logic_vector(7 downto 0);
        tx_start    : in  std_logic;
        tx          : out std_logic;
        busy        : out std_logic
    );
    end component;
    
    component fifo is
    Generic (
        DATA_WIDTH : integer := 8;   -- Largeur standard UART
        FIFO_DEPTH : integer := 64   -- Profondeur (64 octets de mémoire tampon)
    );
    Port ( 
        horloge     : in  STD_LOGIC;
        reset   : in  STD_LOGIC; 
        
        -- Interface Écriture 
        wr_en   : in  STD_LOGIC; 
        din     : in  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
        full    : out STD_LOGIC;
        
        -- Interface Lecture 
        rd_en   : in  STD_LOGIC; 
        dout    : out STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
        empty   : out STD_LOGIC 
    );
    end component;
    
    component consommateur is 
    Port ( 
        horloge     :   in std_logic;
        reset       :   in std_logic;
        
        tx_busy     :   in std_logic;
        fifo_empty  :   in std_logic;
        
        read_fifo   :   out std_logic;
        start_tx    :   out std_logic
    );
    
    end component;
    
    
    component multiplexeur_animation is 
        Port (
        cmd : in std_logic_vector (1 downto 0);
        CE_fsm: in std_logic;
        
        led_breath  : in std_logic_vector (7 downto 0);
        CE_breath   : in std_logic;
        
        R_user : in std_logic_vector (7 downto 0);
        G_user : in std_logic_vector (7 downto 0);
        B_user : in std_logic_vector (7 downto 0);
        
        R : out std_logic_vector (7 downto 0);
        G : out std_logic_vector (7 downto 0);
        B : out std_logic_vector (7 downto 0);
        CE: out std_logic
     );
    end component;
    
    
    component led_animation is
    Generic (
        -- Vitesse de l'effet. 
        -- 100 MHz / 200_000 = 500 Hz (Mise à jour de la valeur 500 fois par seconde)
        -- Pour aller de 0 à 255, ça prendra 0.5 seconde (montée) + 0.5s (descente)
        STEP_DELAY : integer := 200_000 
    );
    Port (
        horloge        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        
        -- C'est cette valeur que vous connecterez à vos modules PWM
        value_out  : out STD_LOGIC_VECTOR(7 downto 0);
        CE_pwm     : out std_logic
    );
    end component;
    

    signal rx_data_to_parser: std_logic_vector (7 downto 0);
    signal wr_en_rx: std_logic;
    
    
    signal sig_ok_fsm : std_logic;
    signal sig_erreur_fsm : std_logic;
    signal sig_CNX_fsm : std_logic;
    
    signal sig_CMD_fsm : std_logic;
    signal user_CMD : std_logic_vector (23 downto 0);
    
    signal sender_busy_s: std_logic;
    
    signal cmd_multiplexeur: std_logic_vector (1 downto 0);

    signal cmd_AT_s : std_logic_vector (7 downto 0);
    signal sending_s : std_logic;
    
    signal tx_fifo_full: std_logic;
    signal wr_en_fifo : std_logic;
    signal instructions: std_logic_vector (7 downto 0);
    
    signal rd_en_s: std_logic;
    signal tx_data: std_logic_vector (7 downto 0);
    signal fifo_empty_s: std_logic;
    signal tx_enable: std_logic;
    signal tx_busy_s: std_logic;
    
    signal data_breath: std_logic_vector (7 downto 0);
    signal R_pwm_s: std_logic_vector (7 downto 0);
    signal G_pwm_s: std_logic_vector (7 downto 0);
    signal B_pwm_s: std_logic_vector (7 downto 0);
    signal CE_fsm_s: std_logic;
    signal CE_breath_s: std_logic;
    signal CE_pwms_s : std_logic;
    
    
    
begin

    recepteur_UART: entity work.uart_recv
    port map(
        clk => HORLOGE,
        reset => RESET,
        rx => rx_esp32,
        dat => rx_data_to_parser,
        dat_en => wr_en_rx
    );
    
    analyseur: entity work.parser
    port map(
        horloge => HORLOGE,
        reset => RESET,
        
        rx_data => rx_data_to_parser,
        rx_dv => wr_en_rx,
        
        -- Sorties
        sig_ok => sig_ok_fsm,
        sig_erreur => sig_erreur_fsm,
        sig_CNX => sig_CNX_fsm,
        
        sig_cmd => sig_cmd_fsm,
        data_cmd => user_CMD
    
    );
    
    sequenceur: entity work.fsm
    port map(
    
        horloge => HORLOGE,
        reset => RESET,
        
        sender_busy => sender_busy_s,
        sig_ok => sig_ok_fsm,
        sig_erreur => sig_erreur_fsm,
        sig_CNX => sig_CNX_fsm,
        sig_cmd => sig_cmd_fsm,

        
        cmd_AT_out => cmd_AT_s,
        sending => sending_s,
        cmd_led => cmd_multiplexeur,
        CE_PWMs => CE_fsm_s
        
    );
    
    
    AT_cammandeur: entity work.sender_instr
    port map(
        horloge => HORLOGE,
        reset => RESET, 
        
        enable  => sending_s,               
        instr => cmd_AT_s,
        fifo_full => tx_fifo_full,      
        
        wr_en => wr_en_fifo,               
        busy => sender_busy_s,               
        adr_AT => instructions
    );
    
    fifo_buffer: entity work.fifo
    port map(
    
        horloge => HORLOGE,
        reset => RESET,
        
        -- Interface Écriture 
        wr_en => wr_en_fifo,
        din => instructions,
        full => tx_fifo_full,
        
        -- Interface Lecture 
        rd_en => rd_en_s, 
        dout => tx_data,
        empty => fifo_empty_s
    );
    
    consommateur_fifo: entity work.consommateur
    port map(
    
        horloge => HORLOGE,
        reset => RESET,
        
        tx_busy => tx_busy_s,
        fifo_empty => fifo_empty_s,
        
        read_fifo => rd_en_s,
        start_tx => tx_enable
        
    );
    
    
    tx_transmetteur: entity work.transmetteur
    port map(
    
        horloge => HORLOGE,
        reset => RESET,
        data_in => tx_data,
        tx_start => tx_enable,
        tx => tx_esp32,
        busy => tx_busy_s
    
    );
    
    choix_animation: entity work.multiplexeur_animation
    port map(
        cmd => cmd_multiplexeur,
        CE_fsm => CE_fsm_s,
        
        led_breath => data_breath,
        CE_breath => CE_breath_s,
        
        R_user => user_CMD (23 downto 16),
        G_user => user_CMD (15 downto 8),
        B_user => user_CMD (7 downto 0),
        
        R => R_pwm_s,
        G  => G_pwm_s,
        B  => B_pwm_s,
        CE => CE_pwms_s
    );
    
    led_breath: entity work.led_animation
    port map(
        horloge => HORLOGE,
        reset => RESET,
        
        -- C'est cette valeur que vous connecterez à vos modules PWM
        value_out => data_breath,
        CE_pwm => CE_breath_s
    );
    
    R_PWM: entity work.PWM
    port map(
        IDATA => R_pwm_s,
        HORLOGE => HORLOGE,
        CE => CE_pwms_s,
        RAZ => RESET, 
        ODATA => LED_R
    );
    
    V_PWM: entity work.PWM
    port map(
        IDATA => G_pwm_s,
        HORLOGE => HORLOGE,
        CE => CE_pwms_s,
        RAZ => RESET, 
        ODATA => LED_V
    );
 
    B_PWM: entity work.PWM
    port map(
        IDATA => B_pwm_s,
        HORLOGE => HORLOGE,
        CE => CE_pwms_s,
        RAZ => RESET, 
        ODATA => LED_B
    );
    
    tx_debugger: entity work.uart_bridge2
    port map(
    
        horloge => HORLOGE,
        reset => RESET,
        tx_terminal => tx_terminal,
        rx_terminal => '1',

        rx_esp32 => rx_esp32
    );
    
    

    
    
    
    


end Behavioral;
