# Flutter / eklentiler icin ProGuard/R8 kurallari.
# Cogu Flutter eklentisi kendi 'keep' kurallarini otomatik getirir; bu yuzden
# bu dosya genelde bos kalir. Bir eklenti release'de calismaz hale gelirse
# (ornegin reflection kullanan), ilgili 'keep' kurali buraya eklenir.

# flutter_local_notifications: bildirim zamanlayici siniflarini koru.
-keep class com.dexterous.** { *; }
