# backhul-swap

مانیتور تانل با قابلیت تعویض پروفایل (bip ↔ tcp) هنگام قطع پینگ و راه‌اندازی مجدد سرویس. پشتیبانی از چند سرویس هم‌زمان (چند سرور ایران و خارج).

---

## نصب با یک دستور

اسکریپت نصب فایل‌ها را دانلود می‌کند و **فقط ویزارد تنظیمات** را اجرا می‌کند؛ از کاربر سؤال می‌پرسد و `config.yml` را می‌سازد. هیچ چیز دیگری خودکار اجرا نمی‌شود. برای شروع مانیتور بعداً خودتان `run.sh` را اجرا کنید.

```bash
curl -sSL https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/main/install.sh | bash
```

**لینک مستقیم اسکریپت نصب:**  
[https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/main/install.sh](https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/main/install.sh)

فایل‌ها در `~/backhul-swap` ذخیره می‌شوند. برای مسیر دیگر:

```bash
INSTALL_DIR=/opt/backhul-swap curl -sSL https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/main/install.sh | bash
```

---

## نصب با Git

```bash
git clone https://github.com/hosseinpv1379/backhul-swap.git
cd backhul-swap
```

---

## نحوه اجرا

**۱. حتماً اول تنظیمات:** از کاربر سؤال می‌پرسد و `config.yml` را می‌سازد (با نصب یک‌دستوری همین کار انجام می‌شود؛ وگرنه دستی):

```bash
bash setup.sh
```

در ویزارد تعداد سرویس‌ها، نام سرویس، مسیر فایل toml، IP پینگ و role را وارد کنید. خروجی در `config.yml` ذخیره می‌شود.

**۲. اجرای مانیتور (بعد از ساخته شدن کانفیگ):**

```bash
bash run.sh
```

یا با کانفیگ دلخواه:

```bash
bash run.sh /path/to/config.yml
```

یا مستقیم:

```bash
bash monitor-and-failover.sh config.yml
```

مانیتور را با `Ctrl+C` متوقف کنید.

---

## اجرا در پس‌زمینه (اختیاری)

```bash
nohup bash run.sh > monitor.log 2>&1 &
```

یا بعد از `setup.sh` می‌توانید سرویس systemd برای خود مانیتور نصب کنید (در ویزارد سؤال می‌پرسد).

---

## فایل‌ها و لینک اسکریپت‌ها

| فایل | توضیح | لینک مستقیم |
|------|--------|--------------|
| `install.sh` | دانلود فایل‌ها + فقط ویزارد setup (ساخت کانفیگ)، بدون اجرای مانیتور | [install.sh](https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/main/install.sh) |
| `run.sh` | اجرای مانیتور (بعد از وجود داشتن config.yml) | [run.sh](https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/main/run.sh) |
| `setup.sh` | ویزارد تعاملی برای ساخت/ویرایش `config.yml` | [setup.sh](https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/main/setup.sh) |
| `monitor-and-failover.sh` | مانیتور پینگ و تعویض پروفایل + ریستارت سرویس | [monitor-and-failover.sh](https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/main/monitor-and-failover.sh) |

فایل `config.yml` بعد از اجرای setup ساخته می‌شود.
