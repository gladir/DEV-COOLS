VERSION 5.00
Begin VB.Form frmHello
   Caption         =   "Exemple Hello World"
   ClientHeight    =   1815
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   4680
   LinkTopic       =   "Form1"
   ScaleHeight     =   1815
   ScaleWidth      =   4680
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton cmdQuitter
      Caption         =   "Quitter"
      Height          =   375
      Left            =   3240
      TabIndex        =   2
      Top             =   1320
      Width           =   1215
   End
   Begin VB.CommandButton cmdSaluer
      Caption         =   "Saluer"
      Default         =   -1  'True
      Height          =   375
      Left            =   3240
      TabIndex        =   1
      Top             =   840
      Width           =   1215
   End
   Begin VB.TextBox txtNom
      Height          =   375
      Left            =   1440
      TabIndex        =   0
      Text            =   "Monde"
      Top             =   240
      Width           =   3015
   End
   Begin VB.Label lblNom
      Caption         =   "Votre nom :"
      Height          =   255
      Left            =   240
      TabIndex        =   4
      Top             =   300
      Width           =   1095
   End
   Begin VB.Label lblMessage
      Caption         =   ""
      ForeColor       =   &H00800000&
      Height          =   375
      Left            =   240
      TabIndex        =   3
      Top             =   840
      Width           =   2775
   End
End
Attribute VB_Name = "frmHello"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private Sub Form_Load()
    lblMessage.Caption = ""
    txtNom.SetFocus
End Sub

Private Sub cmdSaluer_Click()
    If Trim$(txtNom.Text) = "" Then
        MsgBox "Veuillez entrer un nom.", vbExclamation, "Hello World"
        txtNom.SetFocus
        Exit Sub
    End If
    lblMessage.Caption = "Bonjour, " & txtNom.Text & " !"
End Sub

Private Sub txtNom_KeyPress(KeyAscii As Integer)
    ' Entree = equivalent a cliquer sur "Saluer"
    If KeyAscii = vbKeyReturn Then
        Call cmdSaluer_Click
        KeyAscii = 0
    End If
End Sub

Private Sub cmdQuitter_Click()
    Unload Me
End Sub
