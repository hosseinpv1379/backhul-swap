# backhul-swap

مانیتور تانل با قابلیت تعویض پروفایل (bip ↔ tcp) هنگام قطع پینگ و راه‌اندازی مجدد سرویس. پشتیبانی از چند سرویس هم‌زمان (چند سرور ایران و خارج).

---

## نصب

```bash
git clone https://github.com/hosseinpv1379/backhul-swap.git
cd backhul-swap
git checkout main
```

اگر ریپو فقط برنچ `master` داشت، برنچ `main` را همین‌جا بساز و به GitHub پوش کن:

```bash
git checkout -b main
git push -u origin main
```

بعد در GitHub: **Settings → General → Default branch** را روی `main` بگذار.

---

## نحوه اجرا

### روش ۱: یک اسکریپت (پیشنهادی)

اول بار که `config.yml` وجود نداشته باشد، ویزارد تنظیمات اجرا می‌شود؛ بعد مانیتور شروع می‌شود:

```bash
bash run.sh
```

با کانفیگ دلخواه:

```bash
bash run.sh /path/to/config.yml
```

### روش ۲: دو مرحله

**۱. تنظیمات (یک بار):**

```bash
bash setup.sh
```

در ویزارد تعداد سرویس‌ها، نام سرویس، مسیر فایل toml، IP پینگ و role را وارد کنید. خروجی در `config.yml` ذخیره می‌شود.

**۲. اجرای مانیتور:**

```bash
bash monitor-and-failover.sh
```

یا با کانفیگ مشخص:

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

## فایل‌ها

| فایل | توضیح |
|------|--------|
| `run.sh` | نقطه ورود: در صورت نبودن کانفیگ، setup را اجرا می‌کند و بعد مانیتور را شروع می‌کند |
| `setup.sh` | ویزارد تعاملی برای ساخت/ویرایش `config.yml` |
| `monitor-and-failover.sh` | مانیتور پینگ و تعویض پروفایل + ریستارت سرویس |
| `config.yml` | تنظیمات (تعداد سرویس‌ها، cooldown، و برای هر سرویس: نام، unit، فایل toml، IP پینگ، role) |

---

## برنچ

استفاده از برنچ **main**: بعد از clone با `git checkout main` روی همین برنچ باشید.
