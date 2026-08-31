Rem 09_date_time.vbs - Dates et heures

Dim dateTest, heureTest
dateTest = DateSerial(2026, 8, 31)
heureTest = TimeSerial(14, 30, 45)

WScript.Echo "Date actuelle  : " & Date
WScript.Echo "Heure actuelle : " & Time
WScript.Echo "Maintenant     : " & Now
WScript.Echo "Date test      : " & dateTest
WScript.Echo "Annee          : " & Year(dateTest)
WScript.Echo "Mois           : " & Month(dateTest)
WScript.Echo "Jour           : " & Day(dateTest)
WScript.Echo "Jour semaine   : " & Weekday(dateTest)
WScript.Echo "Heure test     : " & heureTest
WScript.Echo "Heure          : " & Hour(heureTest)
WScript.Echo "Minute         : " & Minute(heureTest)
WScript.Echo "Seconde        : " & Second(heureTest)
