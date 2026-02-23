# backhul-swap

مانیتور تانل با تعویض پروفایل (bip ↔ tcp) هنگام قطع پینگ و ریستارت سرویس. چند سرویس هم‌زمان.

---

## اجرا

یک دستور: دانلود و اجرا. بار اول سؤال می‌پرسد، کانفیگ می‌سازد، بعد مانیتور را بالا می‌آورد. کانفیگ پیش‌فرضی وجود ندارد.

```bash
curl -sSL https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/master/install.sh | bash
```

لینک مستقیم اسکریپت نصب:  
[https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/master/install.sh](https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/master/install.sh)

فایل‌ها در `~/backhul-swap` ذخیره می‌شوند. مسیر دیگر:

```bash
INSTALL_DIR=/opt/backhul-swap curl -sSL https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/master/install.sh | bash
```

---

## بعد از نصب

هر وقت خواستی مانیتور را اجرا کنی (بعد از ساخته شدن `config.yml`):

```bash
bash ~/backhul-swap/run.sh
```

با کانفیگ دیگر:

```bash
bash ~/backhul-swap/run.sh /path/to/config.yml
```

متوقف کردن: `Ctrl+C`.

---

## فایل‌ها

| فایل | کار |
|------|-----|
| `install.sh` | دانلود + اجرای run.sh (بار اول: سؤال → config → مانیتور) |
| `run.sh` | اگر کانفیگ نبود: setup سپس مانیتور؛ وگرنه فقط مانیتور |
| `setup.sh` | ویزارد سؤال و ساخت `config.yml` |
| `monitor-and-failover.sh` | مانیتور پینگ و swap و ریستارت سرویس |

`config.yml` فقط بعد از اجرای setup ساخته می‌شود؛ در ریپو وجود ندارد.
