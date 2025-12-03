# Home Lab Raspberry Pi
Raspberry Pi 4

## Services
- [x] Filebrowser
- [x] PiHole
- [x] Plex
- [x] qBitTorrent
- [x] Prowlarr
- [x] Flaresolverr
- [x] Radarr
- [x] Sonarr
- [x] Bazarr
- [x] Homarr
- [x] Ntfy
- [x] Dozzle
- [ ] Firewall

## Dozzle
Generate users.yml:

`docker run -it --rm amir20/dozzle generate admin --password password --email test@email.net --name "John Doe" --user-filter name=foo --user-roles shell > users.yml`