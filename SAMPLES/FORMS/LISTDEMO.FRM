VERSION 5.00
Begin VB.Form frmListDemo
   Caption         =   "Demo ListBox / ComboBox"
   ClientHeight    =   3600
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   4800
   LinkTopic       =   "Form1"
   ScaleHeight     =   3600
   ScaleWidth      =   4800
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton cmdVider
      Caption         =   "Vider la liste"
      Height          =   375
      Left            =   3360
      TabIndex        =   6
      Top             =   1560
      Width           =   1215
   End
   Begin VB.CommandButton cmdRetirer
      Caption         =   "Retirer"
      Height          =   375
      Left            =   3360
      TabIndex        =   5
      Top             =   1080
      Width           =   1215
   End
   Begin VB.CommandButton cmdAjouter
      Caption         =   "Ajouter >>"
      Default         =   -1  'True
      Height          =   375
      Left            =   3360
      TabIndex        =   4
      Top             =   600
      Width           =   1215
   End
   Begin VB.ComboBox cboCategorie
      Height          =   315
      Left            =   1560
      Style           =   2  'Dropdown List
      TabIndex        =   1
      Top             =   600
      Width           =   1695
   End
   Begin VB.TextBox txtArticle
      Height          =   375
      Left            =   1560
      TabIndex        =   0
      Top             =   120
      Width           =   1695
   End
   Begin VB.ListBox lstArticles
      Height          =   2205
      Left            =   120
      TabIndex        =   3
      Top             =   1200
      Width           =   3015
   End
   Begin VB.Label lblCompteur
      Caption         =   "0 article(s)"
      Height          =   255
      Left            =   120
      TabIndex        =   7
      Top             =   3120
      Width           =   1935
   End
   Begin VB.Label lblCategorie
      Caption         =   "Categorie :"
      Height          =   255
      Left            =   240
      TabIndex        =   2
      Top             =   660
      Width           =   1215
   End
   Begin VB.Label lblArticle
      Caption         =   "Article :"
      Height          =   255
      Left            =   240
      TabIndex        =   8
      Top             =   180
      Width           =   1215
   End
End
Attribute VB_Name = "frmListDemo"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private Sub Form_Load()
    cboCategorie.AddItem "Epicerie"
    cboCategorie.AddItem "Quincaillerie"
    cboCategorie.AddItem "Electronique"
    cboCategorie.ListIndex = 0
    Call MettreAJourCompteur
End Sub

Private Sub cmdAjouter_Click()
    If Trim$(txtArticle.Text) = "" Then
        MsgBox "Entrez un nom d'article.", vbExclamation
        txtArticle.SetFocus
        Exit Sub
    End If

    lstArticles.AddItem txtArticle.Text & " (" & cboCategorie.Text & ")"
    txtArticle.Text = ""
    txtArticle.SetFocus
    Call MettreAJourCompteur
End Sub

Private Sub cmdRetirer_Click()
    If lstArticles.ListIndex < 0 Then
        MsgBox "Selectionnez un article a retirer.", vbExclamation
        Exit Sub
    End If
    lstArticles.RemoveItem lstArticles.ListIndex
    Call MettreAJourCompteur
End Sub

Private Sub cmdVider_Click()
    If MsgBox("Vider toute la liste ?", vbQuestion + vbYesNo) = vbYes Then
        lstArticles.Clear
        Call MettreAJourCompteur
    End If
End Sub

Private Sub MettreAJourCompteur()
    lblCompteur.Caption = lstArticles.ListCount & " article(s)"
End Sub

Private Sub lstArticles_DblClick()
    Call cmdRetirer_Click
End Sub
