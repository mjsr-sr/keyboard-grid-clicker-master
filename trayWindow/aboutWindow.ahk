ABOUT()
{
	Gui,Destroy
	Gui,Font,Bold,Lucida Console
	Gui,Add,Text,,DnC (Divide and Conquer)
	Gui,Font,Norm Italic
	Gui,Add,Text,xm,mouse replacement utility
	Gui,Font,Norm
	Gui,Add,Text,xm yp+25,Press Ctrl+* to start. Escape to exit.
	Gui,Add,Text,xm,Numbers (1-9) select the sector in the grid.
	Gui,Add,Text,xm,Right click the tray icon to change settings.
	Gui,Add,Text,xm yp+25,Created using
	Gui,Font,underline
	Gui,Add,Text,xp+97 yp cBlue gAutohotkeyHome,AutoHotkey
	Gui,Font,norm
	Gui,Add,Text,xm yp+25,Inspired by
	Gui,Font,underline
	Gui,Add,Text,xp+83 cBlue gMouserHome,'Mouser' by Adam Pash
	Gui,Show,,About DnC
}