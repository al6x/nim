# Forward 80 to 8080 on Mac OS

Enable

```
echo "
rdr pass inet proto tcp from any to any port 80 -> 127.0.0.1 port 8080
" | sudo pfctl -ef -
sudo pfctl -s nat
```

Disable

```
echo "
" | sudo pfctl -ef -
sudo pfctl -s nat
```

Show

```
sudo pfctl -s rules
```