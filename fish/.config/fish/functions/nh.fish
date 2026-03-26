function nh
  env QT_SCALE_FACTOR=1.7 QT_QPA_PLATFORM=xcb nohup "/home/patrick/.local/share/Newshosting/3.8.9/Newshosting-x86_64.AppImage" \
    >/dev/null 2>&1 </dev/null &
  disown
end
