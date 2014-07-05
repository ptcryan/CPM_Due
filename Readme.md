# CPM Due
This is a CP/M v2.2 computer that uses a Z80 emulator, running on an Arduino
Due. To create it I've pulled together several open source projects including
[avrcpm](http://spritesmods.com/?art=avrcpm) by
[SpritesMods.com](http://spritesmods.com/?art=main),
and [Z80 emulator](http://www.komkon.org/~dekogel/misc.html) by
[Marcel de Kogel](http://www.komkon.org/~dekogel/).

Additionally, I have included CP/M programs & documents from an untold number
of companies and developers in the `cpmapps` directory.

The portions of code that I created to 'glue' all this together are given
under the [GPLv3 license](http://www.gnu.org/licenses/gpl-3.0.txt).

## How to build the application
Building the application is easy. Simply get a copy of `z80due`, compile it, and
load it on your [Arduino Due](http://arduino.cc/en/Main/ArduinoBoardDue)
or [Digistump DigiX](http://digistump.com/products/50) HW.

To create the disk image you'll need to follow the directions in the `tools/
avrcpm/z80` directory to create a 'floppy disk' onto an SD card.

Plug the SD card into the HW and 'boot' the application to get CP/M running.

## How to build the HW
You'll need an Arduino Due in order to run this application. The reason is the
Due is powerful enough with an 84MHz ARM Cortex-M3 to emulate a Z80 at full
speed, and has enough built in RAM to support 64K of RAM (even though this
distribution of CP/M is built for 62K).

But wait, the Due doesn't have a place to put an SD card. Yup. You'll need to
wire in your own SD card adaptor. When you go looking for one be mindful that
the Due doesn't have the same pinout as an Uno, and most SD card shields
won't work with the Due.

To build mine I used an
[SD card breakout board](http://www.adafruit.com/products/254) from
[Adafruit](http://www.adafruit.com), and prototyping shield from [NKC
Electronics](http://www.nkcelectronics.com/MEGAshield-KIT-for-Arduino-MEGA-2560-R3-and-Arduino-DUE_p_309.html)
(I got mine from [Amazon](http://www.amazon.com)). It
allowed me to also add other HW to the 'machine' which was nice.

An alternative shield is available from [SainSmart], and it works fine if all
you want is the SD adaptor for a Due. It's simple and convenient.

If you prefer an all-in-one HW solution you can also use the DigiX. It has a
built-in SD card reader as well as WiFi! (but unused on this project). It would
be really cool if someone(?) got WiFi working with CP/M, but that's for another
time.

|![DigiX](https://s3.amazonaws.com/digistump-resources/images/m/8dab1ef169626edc7d400ed59a31a18a.jpg)|
|:-:|
|**Digistump DigiX**|

|![Due](http://arduino.cc/en/uploads/Main/ArduinoDue_Front_450px.jpg)|
|:-:|
|**Arduino Due**|

## How to create disk images
Creating the disk images is a little tricky. Here's how I did it with OS X.

### OS X
Use the instructions in the 'readme.txt' file to create the CP/M image on
an SD Card. It uses some Terminal commands so you'll have be be comfortable
with doing that.

If you don't have cpmtools already installed you can easily get them using
[Homebrew](https://github.com/Homebrew/homebrew). Once you have that just type:

```
$ brew install cpmtools
```

Be warned! when you finally get to the point of copying the CP/M image to the
sd card be carefull to note the volume name for the card. That might mean
you have to modify the `Makefile` to change the path. Don't blindly run
`make` or you might overwrite something important!

## Where to find this project
This project is hosted on [Github](http://www.github.com) as
[ptcryan/**CPM_Due**](https://www.github.com/ptcryan/CPM_Due). Feel free to contribute as
much as you like!
