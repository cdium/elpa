--  Abstract :
--
--  Generic Emacs background process; parse token stream, return
--  parser actions.
--
--  See gen_run_wisi_parse.ads for a standalone version.
--
--  References :
--
--  [1] On the elisp side, the inter-process protocol is defined in
--  wisi-process-parse.el, functions wisi-process-parse--send-parse
--  and wisi-process-parse--execute.
--
--  [2] On the Ada side, it is defined here, and in
--  wisitoken-wisi_runtime.adb
--
--  Copyright (C) 2017 - 2019 Free Software Foundation, Inc.
--
--  This program is free software; you can redistribute it and/or
--  modify it under terms of the GNU General Public License as
--  published by the Free Software Foundation; either version 3, or (at
--  your option) any later version. This program is distributed in the
--  hope that it will be useful, but WITHOUT ANY WARRANTY; without even
--  the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
--  PURPOSE. See the GNU General Public License for more details. You
--  should have received a copy of the GNU General Public License
--  distributed with this program; see file COPYING. If not, write to
--  the Free Software Foundation, 51 Franklin Street, Suite 500, Boston,
--  MA 02110-1335, USA.

pragma License (GPL);

with WisiToken.Parse.LR.Parser;
with WisiToken.Syntax_Trees;
with Wisi;
generic
   type Parse_Data_Type  is new Wisi.Parse_Data_Type with private;

   Name                                  : in String; --  for Usage, error messages.
   Descriptor                            : in WisiToken.Descriptor;
   Partial_Parse_Active                  : in out Boolean;
   Language_Fixes                        : in WisiToken.Parse.LR.Parser.Language_Fixes_Access;
   Language_Use_Minimal_Complete_Actions : in WisiToken.Parse.LR.Parser.Language_Use_Minimal_Complete_Actions_Access;
   Language_String_ID_Set                : in WisiToken.Parse.LR.Parser.Language_String_ID_Set_Access;

   with procedure Create_Parser
     (Parser                       :    out          WisiToken.Parse.LR.Parser.Parser;
      Language_Fixes               : in              WisiToken.Parse.LR.Parser.Language_Fixes_Access;
      Language_Use_Minimal_Complete_Actions : in
        WisiToken.Parse.LR.Parser.Language_Use_Minimal_Complete_Actions_Access;
      Language_String_ID_Set       : in              WisiToken.Parse.LR.Parser.Language_String_ID_Set_Access;
      Trace                        : not null access WisiToken.Trace'Class;
      User_Data                    : in              WisiToken.Syntax_Trees.User_Data_Access);

procedure Gen_Emacs_Wisi_LR_Parse;