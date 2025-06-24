# Virsh Cheat Sheet

## 🔍 **VM Listing & Info**

| Command                  | Purpose                                              |
| ------------------------ | ---------------------------------------------------- |
| `virsh list`             | List **running** VMs                                 |
| `virsh list --all`       | List **all** VMs                                     |
| `virsh dominfo <vm>`     | Info about a VM                                      |
| `virsh domuuid <vm>`     | Get VM UUID                                          |
| `virsh domifaddr <vm>`   | Get VM IP address (if QEMU guest agent is installed) |
| `virsh domstate <vm>`    | Show power state                                     |
| `virsh domhostname <vm>` | Get hostname (if agent is present)                   |

---

## ⚙️ **Start/Stop VMs**

| Command               | Action                                  |
| --------------------- | --------------------------------------- |
| `virsh start <vm>`    | Start VM                                |
| `virsh shutdown <vm>` | Graceful shutdown                       |
| `virsh destroy <vm>`  | Force shutdown (power off)              |
| `virsh reboot <vm>`   | Reboot VM                               |
| `virsh suspend <vm>`  | Pause VM                                |
| `virsh resume <vm>`   | Resume VM                               |
| `virsh reset <vm>`    | Hard reset (like pressing reset button) |

---

## 📦 **Manage VMs**

| Command                                | Purpose                                    |
| -------------------------------------- | ------------------------------------------ |
| `virsh define <file.xml>`              | Define a VM from XML                       |
| `virsh undefine <vm>`                  | Remove VM definition (doesn’t delete disk) |
| `virsh edit <vm>`                      | Edit VM XML in your `$EDITOR`              |
| `virsh dumpxml <vm>`                   | Show full XML config                       |
| `virsh setmaxmem <vm> <size> --config` | Set max memory                             |
| `virsh setmem <vm> <size> --config`    | Set runtime memory                         |
| `virsh setvcpus <vm> <count> --config` | Set CPU count                              |

---

## 💾 **Disk & Snapshot**

| Command                                  | Purpose                      |
| ---------------------------------------- | ---------------------------- |
| `virsh vol-list default`                 | List volumes in default pool |
| `virsh vol-delete <name> --pool default` | Delete a disk                |
| `virsh snapshot-list <vm>`               | List snapshots               |
| `virsh snapshot-create-as <vm> <name>`   | Create snapshot              |
| `virsh snapshot-revert <vm> <name>`      | Revert to snapshot           |

---

## 🌐 **Networking**

| Command                       | Description        |
| ----------------------------- | ------------------ |
| `virsh net-list --all`        | List networks      |
| `virsh net-start default`     | Start network      |
| `virsh net-autostart default` | Auto-start network |
| `virsh net-destroy default`   | Stop network       |
| `virsh net-edit <name>`       | Edit network XML   |

---

## ⚙️ **Autostart & Boot Options**

| Command                            | Purpose                        |
| ---------------------------------- | ------------------------------ |
| `virsh autostart <vm>`             | Start VM automatically on boot |
| `virsh autostart <vm> --disable`   | Disable autostart              |
| `virsh set-boot <vm> --boot cdrom` | Change boot order              |

---

## 🧠 **Helpful Flags**

* `--config`: Persist across reboot
* `--live`: Apply immediately to running VM
* `--current`: Apply to current session only

---

## ✅ Common Use Cases

```bash
virsh list --all                       # See all VMs
virsh start aditi                      # Start a VM
virsh shutdown aditi                   # Shut it down
virsh destroy aditi                    # Force off
virsh domifaddr aditi                  # Get guest IP
virsh edit aditi                       # Modify config
virsh snapshot-create-as aditi snap1   # Take a snapshot
```

