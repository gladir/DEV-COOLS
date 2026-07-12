VERSION 5.00
Begin VB.Form frmCalculator
   Caption         =   "Calculatrice"
   ClientHeight    =   3690
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   2415
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   ScaleHeight     =   3690
   ScaleWidth      =   2415
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton cmdOp
      Caption         =   "="
      Height          =   495
      Index           =   4
      Left            =   1800
      TabIndex        =   16
      Top             =   3000
      Width           =   495
   End
   Begin VB.CommandButton cmdOp
      Caption         =   "/"
      Height          =   495
      Index           =   3
      Left            =   1800
      TabIndex        =   15
      Top             =   2400
      Width           =   495
   End
   Begin VB.CommandButton cmdOp
      Caption         =   "x"
      Height          =   495
      Index           =   2
      Left            =   1800
      TabIndex        =   14
      Top             =   1800
      Width           =   495
   End
   Begin VB.CommandButton cmdOp
      Caption         =   "-"
      Height          =   495
      Index           =   1
      Left            =   1800
      TabIndex        =   13
      Top             =   1200
      Width           =   495
   End
   Begin VB.CommandButton cmdOp
      Caption         =   "+"
      Height          =   495
      Index           =   0
      Left            =   1800
      TabIndex        =   12
      Top             =   600
      Width           =   495
   End
   Begin VB.CommandButton cmdC
      Caption         =   "C"
      Height          =   495
      Left            =   1200
      TabIndex        =   11
      Top             =   3000
      Width           =   495
   End
   Begin VB.CommandButton cmdChiffre
      Caption         =   "0"
      Height          =   495
      Index           =   0
      Left            =   120
      TabIndex        =   10
      Top             =   3000
      Width           =   495
   End
   Begin VB.CommandButton cmdChiffre
      Caption         =   "9"
      Height          =   495
      Index           =   9
      Left            =   1200
      TabIndex        =   9
      Top             =   2400
      Width           =   495
   End
   Begin VB.CommandButton cmdChiffre
      Caption         =   "8"
      Height          =   495
      Index           =   8
      Left            =   660
      TabIndex        =   8
      Top             =   2400
      Width           =   495
   End
   Begin VB.CommandButton cmdChiffre
      Caption         =   "7"
      Height          =   495
      Index           =   7
      Left            =   120
      TabIndex        =   7
      Top             =   2400
      Width           =   495
   End
   Begin VB.CommandButton cmdChiffre
      Caption         =   "6"
      Height          =   495
      Index           =   6
      Left            =   1200
      TabIndex        =   6
      Top             =   1800
      Width           =   495
   End
   Begin VB.CommandButton cmdChiffre
      Caption         =   "5"
      Height          =   495
      Index           =   5
      Left            =   660
      TabIndex        =   5
      Top             =   1800
      Width           =   495
   End
   Begin VB.CommandButton cmdChiffre
      Caption         =   "4"
      Height          =   495
      Index           =   4
      Left            =   120
      TabIndex        =   4
      Top             =   1800
      Width           =   495
   End
   Begin VB.CommandButton cmdChiffre
      Caption         =   "3"
      Height          =   495
      Index           =   3
      Left            =   1200
      TabIndex        =   3
      Top             =   1200
      Width           =   495
   End
   Begin VB.CommandButton cmdChiffre
      Caption         =   "2"
      Height          =   495
      Index           =   2
      Left            =   660
      TabIndex        =   2
      Top             =   1200
      Width           =   495
   End
   Begin VB.CommandButton cmdChiffre
      Caption         =   "1"
      Height          =   495
      Index           =   1
      Left            =   120
      TabIndex        =   1
      Top             =   1200
      Width           =   495
   End
   Begin VB.TextBox txtAffichage
      Alignment       =   1  'Right Justify
      Height          =   495
      Left            =   120
      Locked          =   -1  'True
      TabIndex        =   0
      Text            =   "0"
      Top             =   120
      Width           =   2175
   End
End
Attribute VB_Name = "frmCalculator"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private dValeurCourante As Double
Private dOperande As Double
Private sOperateur As String
Private bAttenteSaisie As Boolean

Private Sub Form_Load()
    Call RemettreAZero
End Sub

Private Sub RemettreAZero()
    dValeurCourante = 0
    dOperande = 0
    sOperateur = ""
    bAttenteSaisie = True
    txtAffichage.Text = "0"
End Sub

Private Sub cmdChiffre_Click(Index As Integer)
    If bAttenteSaisie Or txtAffichage.Text = "0" Then
        txtAffichage.Text = CStr(Index)
        bAttenteSaisie = False
    Else
        txtAffichage.Text = txtAffichage.Text & CStr(Index)
    End If
End Sub

Private Sub cmdOp_Click(Index As Integer)
    dOperande = CDbl(txtAffichage.Text)

    If sOperateur <> "" And sOperateur <> "=" Then
        dValeurCourante = Calculer(dValeurCourante, dOperande, sOperateur)
        txtAffichage.Text = CStr(dValeurCourante)
    Else
        dValeurCourante = dOperande
    End If

    Select Case Index
        Case 0
            sOperateur = "+"
        Case 1
            sOperateur = "-"
        Case 2
            sOperateur = "x"
        Case 3
            sOperateur = "/"
        Case 4
            sOperateur = "="
    End Select
    bAttenteSaisie = True
End Sub

Private Function Calculer(ByVal A As Double, ByVal B As Double, _
                           ByVal Op As String) As Double
    Select Case Op
        Case "+"
            Calculer = A + B
        Case "-"
            Calculer = A - B
        Case "x"
            Calculer = A * B
        Case "/"
            If B = 0 Then
                MsgBox "Division par zero.", vbCritical, "Erreur"
                Calculer = 0
            Else
                Calculer = A / B
            End If
        Case Else
            Calculer = B
    End Select
End Function

Private Sub cmdC_Click()
    Call RemettreAZero
End Sub
