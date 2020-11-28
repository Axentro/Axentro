# Install

Store in file: `/etc/systemd/system/axen.service`
Then call: `sudo systemctl daemon-reload`
Enable service: `sudo systemctl enable axen.service`
Start service: `sudo systemctl start axen.service`

Quick logs: `journalctl -r`

Logs: store in file: `/etc/rsyslog.d/49-axentro.conf`
Then call: `sudo systemctl restart rsyslog`
And then: `sudo systemctl restart axen`

