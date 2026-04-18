FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install 32-bit support, Wine (stable), and SteamCMD dependencies.
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      wget \
      gnupg2 \
      winbind \
      curl \
      unzip \
      lib32gcc-s1 \
      lib32stdc++6 \
      procps \
      util-linux \
      rsync \
      vim-tiny && \
    apt-get install -y wine && \
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
ENV SERVER_EXE=R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe
ENV SERVER_ARGS=
ENV SKIP_UPDATE=0

WORKDIR /home/steam

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
