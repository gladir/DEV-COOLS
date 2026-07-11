VERSION 5.00
Begin VB.Form frmLogin
   Caption         =   "Connexion"
   ClientHeight    =   2280
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   3960
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   2280
   ScaleWidth      =   3960
   StartUpPosition =   2  'CenterScreen
   Begin VB.CheckBox chkMemoriser
      Caption         =   "Se souvenir de moi"
      Height          =   255
      Left            =   240
      TabIndex        =   4
      Top             =   1200
      Width           =   2415
   End
   Begin VB.CommandButton cmdAnnuler
      Cancel          =   -1  'True
      Caption         =   "Annuler"
      Height          =   375
      Left            =   2640
      TabIndex        =   6
      Top             =   1680
      Width           =   1095
   End
   Begin VB.CommandButton cmdConnecter
      Caption         =   "Connexion"
      Default         =   -1  'True
      Height          =   375
      Left            =   1440
      TabIndex        =   5
      Top             =   1680
      Width           =   1095
   End
   Begin VB.TextBox txtMotDePasse
      Height          =   375
      IMEMode         =   3  'DISABLE
      Left            =   1440
      PasswordChar    =   "*"
      TabIndex        =   3
      Top             =   720
      Width           =   2295
   End
   Begin VB.TextBox txtUtilisateur
      Height          =   375
      Left            =   1440
      TabIndex        =   1
      Top             =   240
      Width           =   2295
   End
   Begin VB.Label lblStatut
      Caption         =   ""
      ForeColor       =   &H000000FF&
      Height          =   255
      Left            =   240
      TabIndex        =   7
      Top             =   1440
      Width           =   3495
   End
   Begin VB.Label lblMotDePasse
      Caption         =   "Mot de passe :"
      Height          =   255
      Left            =   240
      TabIndex        =   2
      Top             =   780
      Width           =   1215
   End
   Begin VB.Label lblUtilisateur
      Caption         =   "Utilisateur :"
      Height          =   255
      Left            =   240
      TabIndex        =   0
      Top             =   300
      Width           =   1095
   End
End
Attribute VB_Name = "frmLogin"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private Const MAX_TENTATIVES As Integer = 3
Private nTentatives As Integer

Private Sub Form_Load()
    nTentatives = 0
    lblStatut.Caption = ""
    txtUtilisateur.SetFocus
End Sub

Private Sub cmdConnecter_Click()
    If Trim$(txtUtilisateur.Text) = "" Then
        lblStatut.Caption = "Le nom d'utilisateur est requis."
        txtUtilisateur.SetFocus
        Exit Sub
    End If

    If VerifierIdentifiants(txtUtilisateur.Text, txtMotDePasse.Text) Then
        MsgBox "Bienvenue, " & txtUtilisateur.Text & " !", vbInformation, _
            "Connexion reussie"
        If chkMemoriser.Value = vbChecked Then
            Call MemoriserUtilisateur(txtUtilisateur.Text)
        End If
        Unload Me
    Else
        nTentatives = nTentatives + 1
        lblStatut.Caption = "Identifiants incorrects (" & nTentatives & _
            "/" & MAX_TENTATIVES & ")"
        txtMotDePasse.Text = ""
        txtMotDePasse.SetFocus
        If nTentatives >= MAX_TENTATIVES Then
            MsgBox "Nombre maximal de tentatives atteint.", vbCritical, _
                "Connexion refusee"
            Unload Me
        End If
    End If
End Sub

Private Function VerifierIdentifiants(ByVal sUser As String, _
                                       ByVal sPass As String) As Boolean
    ' Verification de demonstration uniquement.
    VerifierIdentifiants = (LCase$(sUser) = "admin" And sPass = "vb6")
End Function

Private Sub MemoriserUtilisateur(ByVal sUser As String)
    SaveSetting "ExempleLogin", "Options", "DernierUtilisateur", sUser
End Sub

Private Sub cmdAnnuler_Click()
    Unload Me
End Sub

Private Sub txtMotDePasse_KeyPress(KeyAscii As Integer)
    If KeyAscii = vbKeyReturn Then
        Call cmdConnecter_Click
        KeyAscii = 0
    End If
End Sub
