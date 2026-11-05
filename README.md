# لمّتنا

تطبيق أندرويد خاص بالعيلة: ريلز وستوري، بدخول بدعوة أو موافقة الأدمن.

- **التطبيق:** Flutter
- **الخلفية:** Supabase (تسجيل دخول، قاعدة بيانات، تخزين خاص)
- **البناء والتوزيع:** GitHub Actions يبني APK موقّع وينشره على Releases

## رابط التنزيل الثابت

`https://github.com/basemelsayed540/family-reels/releases/download/latest-apk/lammatna.apk`

## إعداد لمرة واحدة

1. **Supabase:** افتح SQL Editor وشغّل `supabase/setup.sql` ثم `supabase/social.sql` (المنشورات والتعليقات والإشعارات) ثم `supabase/reactions.sql` (الريأكشنز الستة) ثم `supabase/members.sql` (نشر كل الأعضاء + التعديل والحذف) ثم `supabase/new_video_notifications.sql` (إشعارات الفيديوهات الجديدة).
2. **Supabase:** من Authentication ثم Sign In / Providers ثم Email، اقفل **Confirm email**.
3. **GitHub:** من Settings ثم Secrets and variables ثم Actions أضف سرّين:
   - `KEYSTORE_BASE64`
   - `KEYSTORE_PASSWORD`
4. **GitHub:** من تبويب Actions شغّل **Build APK** (Run workflow).
5. نزّل الـ APK من الرابط أعلاه وثبّته، وسجّل أول حساب (هو الأدمن تلقائيًا).

## التحديثات

كل تعديل يُرفع على فرع `main` يبني نسخة جديدة. التطبيق يفحص وجود نسخة أحدث عند الفتح
ويعرض زر "حدّث الآن". احتفظ بنسخة احتياطية من مفتاح التوقيع، فبدونه لن تُثبّت التحديثات فوق النسخة القديمة.
