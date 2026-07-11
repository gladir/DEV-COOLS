VERSION 5.00
Begin VB.Form frmMenuDemo
   Caption         =   "Demo Menu"
   ClientHeight    =   3195
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   4800
   LinkTopic       =   "Form1"
   ScaleHeight     =   3195
   ScaleWidth      =   4800
   StartUpPosition =   3  'Windows Default
   Begin VB.TextBox txtZone
      Height          =   2895
      Left            =   120
      MultiLine       =   -1  'True
      ScrollBars      =   2  'Vertical
      TabIndex        =   0
      Top             =   120
      Width           =   4575
   End
   Begin VB.Menu mnuFichier
      Caption         =   "&Fichier"
      Begin VB.Menu mnuFichierNouveau
         Caption         =   "&Nouveau"
         Shortcut        =   ^N
      End
      Begin VB.Menu mnuFichierOuvrir
         Caption         =   "&Ouvrir..."
         Shortcut        =   ^O
      End
      Begin VB.Menu mnuFichierEnregistrer
         Caption         =   "&Enregistrer"
         Shortcut        =   ^S
      End
      Begin VB.Menu mnuFichierSep1
         Caption         =   "-"
      End
      Begin VB.Menu mnuFichierQuitter
         Caption         =   "&Quitter"
      End
   End
   Begin VB.Menu mnuEdition
      Caption         =   "&Edition"
      Begin VB.Menu mnuEditionCouper
         Caption         =   "&Couper"
         Shortcut        =   ^X
      End
      Begin VB.Menu mnuEditionCopier
         Caption         =   "Co&pier"
         Shortcut        =   ^C
      End
      Begin VB.Menu mnuEditionColler
         Caption         =   "C&oller"
         Shortcut        =   ^V
      End
      Begin VB.Menu mnuEditionSep1
         Caption         =   "-"
      End
      Begin VB.Menu mnuEditionEffacer
         Caption         =   "&Effacer tout"
      End
   End
   Begin VB.Menu mnuAffichage
      Caption         =   "&Affichage"
      Begin VB.Menu mnuAffichageAgrandir
         Caption         =   "Police &plus grande"
      End
      Begin VB.Menu mnuAffichageReduire
         Caption         =   "Police plus &petite"
      End
   End
   Begin VB.Menu mnuAide
      Caption         =   "&?"
      Begin VB.Menu mnuAideAPropos
         Caption         =   "&A propos..."
      End
   End
End
Attribute VB_Name = "frmMenuDemo"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private sFichierCourant As String

Private Sub Form_Load()
    sFichierCourant = ""
    txtZone.Text = ""
End Sub

Private Sub mnuFichierNouveau_Click()
    If Len(txtZone.Text) > 0 Then
        If MsgBox("Le contenu actuel sera perdu. Continuer ?", _
            vbQuestion + vbYesNo) = vbNo Then
            Exit Sub
        End If
    End If
    txtZone.Text = ""
    sFichierCourant = ""
    Me.Caption = "Demo Menu"
End Sub

Private Sub mnuFichierOuvrir_Click()
    Dim sChemin As String
    Dim iFichier As Integer
    Dim sLigne As String
    Dim sContenu As String

    sChemin = InputBox("Chemin du fichier a ouvrir :", "Ouvrir")
    If sChemin = "" Then Exit Sub

    iFichier = FreeFile
    Open sChemin For Input As #iFichier
    Do While Not EOF(iFichier)
        Line Input #iFichier, sLigne
        sContenu = sContenu & sLigne & vbCrLf
    Loop
    Close #iFichier

    txtZone.Text = sContenu
    sFichierCourant = sChemin
    Me.Caption = "Demo Menu - " & sChemin
End Sub

Private Sub mnuFichierEnregistrer_Click()
    Dim iFichier As Integer

    If sFichierCourant = "" Then
        sFichierCourant = InputBox("Enregistrer sous :", "Enregistrer")
        If sFichierCourant = "" Then Exit Sub
    End If

    iFichier = FreeFile
    Open sFichierCourant For Output As #iFichier
    Print #iFichier, txtZone.Text
    Close #iFichier

    MsgBox "Fichier enregistre.", vbInformation
End Sub

Private Sub mnuFichierQuitter_Click()
    Unload Me
End Sub

Private Sub mnuEditionCouper_Click()
    Clipboard.SetText txtZone.SelText
    txtZone.SelText = ""
End Sub

Private Sub mnuEditionCopier_Click()
    Clipboard.SetText txtZone.SelText
End Sub

Private Sub mnuEditionColler_Click()
    txtZone.SelText = Clipboard.GetText()
End Sub

Private Sub mnuEditionEffacer_Click()
    txtZone.Text = ""
End Sub

Private Sub mnuAffichageAgrandir_Click()
    If txtZone.Font.Size < 32 Then
        txtZone.Font.Size = txtZone.Font.Size + 2
    End If
End Sub

Private Sub mnuAffichageReduire_Click()
    If txtZone.Font.Size > 6 Then
        txtZone.Font.Size = txtZone.Font.Size - 2
    End If
End Sub

Private Sub mnuAideAPropos_Click()
    MsgBox "Demo Menu" & vbCrLf & "Exemple de fichier .FRM Visual Basic 6.", _
        vbInformation, "A propos"
End Sub
