FROM tensorflow/tensorflow:latest
MAINTAINER Alexander Wellbrock <a.wellbrock@mailbox.org>
MAINTAINER Josh Ward <ward.joshua92@yahoo.com>

### X11 server: inspired by suchja/x11server and suchja/wine ###

# first create user and group for all the X Window stuff
# required to do this first so we have consistent uid/gid between server and client container

#NOTE: if you ever make a dockerfile DONT DO THIS. Break up the commands 
#      for layered build dependency optimization and better error reporting.
RUN addgroup --system starcraft \
  && adduser \
    --home /home/starcraft \
    --disabled-password \
    --shell /bin/bash \
    --gecos "user for running starcraft brood war" \
    --ingroup starcraft \
    --quiet \
    starcraft \
  && adduser starcraft sudo

# Install packages for building the image
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    p7zip \
    software-properties-common \
    vim \
    sudo \
    apt-transport-https \
    winbind

# Install packages required for connecting against X Server
RUN apt-get update 
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata
RUN apt-get install --no-install-recommends -y
RUN apt-get install --no-install-recommends xvfb -y
RUN apt-get install --no-install-recommends xauth -y
RUN apt-get install --no-install-recommends x11vnc -y
RUN apt-get install --no-install-recommends x11-utils -y
RUN apt-get install --no-install-recommends x11-xserver-utils -y

ENV DISPLAY :0.0

# Define which versions we need
ENV WINE_MONO_VERSION 4.6.4
ENV WINE_GECKO_VERSION 2.47

# Get Wine keys
RUN curl -SL https://dl.winehq.org/wine-builds/winehq.key | apt-key add - 
RUN apt-add-repository 'https://dl.winehq.org/wine-builds/ubuntu/ main'

# add x32 architecture toolchain 
RUN dpkg --add-architecture i386 
RUN apt-get update 
RUN apt-get upgrade -y

# install graphics dependencies
#RUN sudo apt-get install libgnutls30:i386 libldap-2.4-2:i386 libgpg-error0:i386 libxml2:i386 libasound2-plugins:i386 libsdl2-2.0-0:i386 libfreetype6:i386 libdbus-1-3:i386 libsqlite3-0:i386 -y

# Install wine and related packages
# TODO: fix this wget-curl descrepency
RUN apt-get install wget 
RUN wget https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_18.04/Release.key
RUN apt-key add Release.key
RUN apt-add-repository 'deb https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_18.04/ ./'
RUN apt update
RUN apt install libfaudio0 libasound2-plugins:i386 -y

RUN apt-get install -y --no-install-recommends winehq-stable
RUN rm -rf /var/lib/apt/lists/*

# Use the latest version of winetricks
RUN curl -SL 'https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks' -o /usr/local/bin/winetricks \
  && chmod +x /usr/local/bin/winetricks

ENV WINEPREFIX=/home/starcraft/.wine 
ENV WINEARCH=win32

# These package are necessery for the init of wine
# However they should not be removed because wine will then complain
# that they are gone, blocking all other gui applications.
RUN mkdir /opt/wine-stable/share/wine/mono \
    && curl -L https://dl.winehq.org/wine/wine-mono/4.6.4/wine-mono-4.6.4.msi -o /opt/wine-stable/share/wine/mono/wine-mono-4.6.4.msi
RUN mkdir /opt/wine-stable/share/wine/gecko \
    && curl -L https://dl.winehq.org/wine/wine-gecko/2.47/wine_gecko-2.47-x86.msi -o /opt/wine-stable/share/wine/gecko/wine_gecko-2.47-x86.msi

# TODO: Fix 
# # Starting an x server before running wine init prevents some errors
RUN Xvfb :0 -auth ~/.Xauthority -screen 0 1024x768x24 >> /var/log/xvfb.log 2>&1 &
RUN su -c "wine wineboot --init" starcraft 
RUN su -c "winetricks -q vcrun2013" starcraft

ENV BOT_DIR /home/starcraft/.wine/drive_c/bot
ENV BOT_PATH=$BOT_DIR/bot.dll BOT_DEBUG_PATH=$BOT_DIR/bot_d.dll

# Volume to place your bot inside
VOLUME $BOT_DIR
WORKDIR $BOT_DIR

# Supply your copy of StarCraft within data/StarCraft
# At least the directory should be there...
ENV STARCRAFT /home/starcraft/.wine/drive_c/StarCraft
ADD data/StarCraft/ $STARCRAFT

# Get BWAPI version 412
ENV BWAPI_DIR /home/starcraft/.wine/drive_c/bwapi/
RUN curl -L https://github.com/lionax/bwapi/releases/download/v4.1.2/BWAPI-4.1.2.zip -o /tmp/bwapi.zip \
   && unzip /tmp/bwapi.zip -d $BWAPI_DIR \
      && mv $BWAPI_DIR/BWAPI/* $BWAPI_DIR \
      && rm -R $BWAPI_DIR/BWAPI \
      && rm /tmp/bwapi.zip \
      && chmod 755 -R $BWAPI_DIR

# Get bwapi-data as of version 412
RUN curl -L https://github.com/lionax/bwapi/releases/download/v4.1.2/bwapi-data-4.1.2.zip -o /tmp/bwapi-data.zip \
   && unzip /tmp/bwapi-data.zip -d $STARCRAFT \
      && rm /tmp/bwapi-data.zip \
      && chmod 755 -R $STARCRAFT/bwapi-data

RUN chown -R starcraft:starcraft /home/starcraft/

ADD entrypoint.sh /bin/entrypoint
RUN chmod +x /bin/entrypoint

#force update and upgrade 
#bloated but necessary for drivers?
#RUN apt upgrade 


ENTRYPOINT ["entrypoint"]
