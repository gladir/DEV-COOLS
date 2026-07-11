VERSION 5.00
Begin VB.Form frmTimerDemo
   Caption         =   "Demo Timer - Chronometre"
   ClientHeight    =   1935
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   3300
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   ScaleHeight     =   1935
   ScaleWidth      =   3300
   StartUpPosition =   3  'Windows Default
   Begin VB.Timer tmrChrono
      Interval        =   10
      Left            =   2760
      Top             =   1320
   End
   Begin VB.CommandButton cmdRAZ
      Caption         =   "R.A.Z."
      Height          =   375
      Left            =   2160
      TabIndex        =   2
      Top             =   1080
      Width           =   975
   End
   Begin VB.CommandButton cmdArreter
      Caption         =   "Arreter"
      Enabled         =   0   'False
      Height          =   375
      Left            =   1080
      TabIndex        =   1
      Top             =   1080
      Width           =   975
   End
   Begin VB.CommandButton cmdDemarrer
      Caption         =   "Demarrer"
      Height          =   375
      Left            =   120
      TabIndex        =   0
      Top             =   1080
      Width           =   855
   End
   Begin VB.Label lblChrono
      Alignment       =   2  'Center
      Caption         =   "00:00.00"
      BeginProperty Font
         Name            =   "Courier New"
         Size            =   18
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   615
      Left            =   120
      TabIndex        =   3
      Top             =   240
      Width           =   3015
   End
End
Attribute VB_Name = "frmTimerDemo"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private lCentiemes As Long

Private Sub Form_Load()
    lCentiemes = 0
    tmrChrono.Enabled = False
    Call RafraichirAffichage
End Sub

Private Sub cmdDemarrer_Click()
    tmrChrono.Enabled = True
    cmdDemarrer.Enabled = False
    cmdArreter.Enabled = True
    cmdRAZ.Enabled = False
End Sub

Private Sub cmdArreter_Click()
    tmrChrono.Enabled = False
    cmdDemarrer.Enabled = True
    cmdArreter.Enabled = False
    cmdRAZ.Enabled = True
End Sub

Private Sub cmdRAZ_Click()
    lCentiemes = 0
    Call RafraichirAffichage
End Sub

Private Sub tmrChrono_Timer()
    lCentiemes = lCentiemes + 1
    Call RafraichirAffichage
End Sub

Private Sub RafraichirAffichage()
    Dim lMinutes As Long
    Dim lSecondes As Long
    Dim lReste As Long

    lMinutes = lCentiemes \ 6000
    lReste = lCentiemes Mod 6000
    lSecondes = lReste \ 100
    lReste = lReste Mod 100

    lblChrono.Caption = Format$(lMinutes, "00") & ":" & _
        Format$(lSecondes, "00") & "." & Format$(lReste, "00")
End Sub
