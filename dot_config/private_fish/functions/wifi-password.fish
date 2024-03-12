function wifi-password
  set ssid (networksetup -getairportnetwork en0 | awk -F": " '{print $2}')
  security find-generic-password -a 'AirPort network password' -wa $ssid
end