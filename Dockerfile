FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install 32-bit support, Wine staging, Xvfb, and SteamCMD dependencies.
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      wget \
      gnupg2 \
      xvfb \
      winbind \
      dbus-x11 \
      curl \
      unzip \
      lib32gcc-s1 \
      lib32stdc++6 \
      procps \
      util-linux \
      rsync \
      vim-tiny && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources && \
    apt-get update && \
    apt-get install -y --install-recommends winehq-staging && \
    mkdir -p /home/steam/steamcmd && \
    cd /home/steam/steamcmd && \
    wget -qO- "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Runtime defaults are overridable in docker-compose.
ENV HOME=/home/steam
ENV WINEPREFIX=/home/steam/windrose/pfx
ENV WINEARCH=win64
ENV WINEDEBUG=-all
ENV WINEESYNC=1
ENV WINEFSYNC=1
ENV INSTALL_DIR=/home/steam/windrose
ENV APP_ID=4129620
ENV SERVER_EXE=StartServerForeground.bat
ENV SERVER_ARGS=
ENV SKIP_UPDATE=0

WORKDIR /home/steam

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
