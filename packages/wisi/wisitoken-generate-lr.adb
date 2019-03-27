--  Abstract :
--
--  See spec.
--
--  Copyright (C) 2017 - 2019 Free Software Foundation, Inc.
--
--  This library is free software;  you can redistribute it and/or modify it
--  under terms of the  GNU General Public License  as published by the Free
--  Software  Foundation;  either version 3,  or (at your  option) any later
--  version. This library is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN-
--  TABILITY or FITNESS FOR A PARTICULAR PURPOSE.

--  As a special exception under Section 7 of GPL version 3, you are granted
--  additional permissions described in the GCC Runtime Library Exception,
--  version 3.1, as published by the Free Software Foundation.

pragma License (GPL);

with Ada.Strings.Fixed;
with Ada.Text_IO;
with System.Multiprocessors;
with WisiToken.Generate;
package body WisiToken.Generate.LR is

   package RHS_Set is new SAL.Gen_Unbounded_Definite_Vectors (Natural, Boolean, Default_Element => False);
   type Token_ID_RHS_Set is array (Token_ID range <>) of RHS_Set.Vector;

   type Token_ID_Array_Positive is array (Token_ID range <>) of Positive;

   ----------
   --  Body subprograms, alphabetical

   function Find
     (Symbol      : in Token_ID;
      Action_List : in Action_Node_Ptr)
     return Action_Node_Ptr
   is
      Action_Node : Action_Node_Ptr := Action_List;
   begin
      while Action_Node /= null loop
         if Action_Node.Symbol = Symbol then
            return Action_Node;
         end if;
         Action_Node := Action_Node.Next;
      end loop;

      return null;
   end Find;

   function Min
     (Item    : in RHS_Sequence_Arrays.Vector;
      RHS_Set : in LR.RHS_Set.Vector)
     return Integer
   is
      use all type Ada.Containers.Count_Type;
      Min_Length : Ada.Containers.Count_Type := Ada.Containers.Count_Type'Last;
      Min_RHS    : Natural                   := Natural'Last;
   begin
      for RHS in Item.First_Index .. Item.Last_Index loop
         if RHS_Set (RHS) and then Min_Length > Item (RHS).Sequence.Length then
               Min_Length := Item (RHS).Sequence.Length;
               Min_RHS    := RHS;
         end if;
      end loop;
      if Min_RHS = Natural'Last then
         raise SAL.Programmer_Error with "nonterm has no minimum terminal sequence";
      else
         return Min_RHS;
      end if;
   end Min;

   procedure Terminal_Sequence
     (Grammar         : in     WisiToken.Productions.Prod_Arrays.Vector;
      Descriptor      : in     WisiToken.Descriptor;
      All_Sequences   : in out Minimal_Sequence_Array;
      All_Set         : in out Token_ID_Set;
      RHS_Set         : in out Token_ID_RHS_Set;
      Recursing       : in out Token_ID_Set;
      Recursing_Index : in out Token_ID_Array_Positive;
      Nonterm         : in     Token_ID)
   is
      use Ada.Containers;
      use Token_ID_Arrays;

      subtype Terminals is Token_ID range Descriptor.First_Terminal .. Descriptor.Last_Terminal;

      Prod : Productions.Instance renames Grammar (Nonterm);

      Skipped_Recursive : Boolean := False;
   begin
      --  We get here because All_Sequences (Nonterm) has not been comptued
      --  yet. Attempt to compute All_Sequences (Nonterm); it may not
      --  succeed due to recursion. If successful, set All_Set (Nonterm)
      --  True.
      --
      --  In a useful grammar, all direct and indirect recursive nonterms
      --  have a non-recursive minimal terminal sequence; finding it will
      --  break the recursion, allowing this algorithm to complete. This is
      --  checked in Compute_Minimal_Terminal_Sequences.

      --  Fill All_Sequences (Nonterm) with terminals from each production
      --  for Nonterm. We set partial results so recursion can be resolved.
      if All_Sequences (Nonterm).Length = 0 then
         All_Sequences (Nonterm).Set_First_Last (Prod.RHSs.First_Index, Prod.RHSs.Last_Index); -- defaults empty
         RHS_Set (Nonterm).Set_First_Last (Prod.RHSs.First_Index, Prod.RHSs.Last_Index); -- defaults False
      end if;

      for RHS in Prod.RHSs.First_Index .. Prod.RHSs.Last_Index loop
         if not RHS_Set (Nonterm)(RHS) then
            if Prod.RHSs (RHS).Tokens.Length = 0 then
               RHS_Set (Nonterm)(RHS) := True;
               if Trace_Generate > Extra then
                  Ada.Text_IO.Put_Line (Trimmed_Image (Production_ID'(Nonterm, RHS)) & " => () empty");
               end if;

            else
               for I in Prod.RHSs (RHS).Tokens.First_Index .. Prod.RHSs (RHS).Tokens.Last_Index loop
                  Recursing_Index (Nonterm) := I;
                  declare
                     ID : Token_ID renames Prod.RHSs (RHS).Tokens (I);
                  begin
                     if ID in Terminals then
                        All_Sequences (Nonterm) (RHS).Sequence.Append (ID);

                     else
                        if not All_Set (ID) then
                           --  Need to compute some RHSs of ID

                           if ID = Nonterm or Recursing (ID) then
                              --  Nonterm is mutually recursive with itself or some other.
                              All_Sequences (Nonterm)(RHS).Left_Recursive := I = Positive'First and
                                (ID = Nonterm or Recursing_Index (ID) = Positive'First);

                              if (for some RHS of RHS_Set (ID) => RHS) then
                                 --  There is a minimal sequence for ID; use it
                                 null;
                              else
                                 if Trace_Generate > Extra then
                                    Ada.Text_IO.Put_Line
                                      (Trimmed_Image (Production_ID'(Nonterm, RHS)) & "." & Trimmed_Image (I) & " => " &
                                         (if ID = Nonterm
                                          then "direct recursive"
                                          else "indirect recursive " & Image (ID, Descriptor)));
                                 end if;

                                 All_Sequences (Nonterm)(RHS).Left_Recursive := False;
                                 All_Sequences (Nonterm)(RHS).Sequence.Clear;
                                 goto Skip;
                              end if;
                           else
                              Recursing (ID) := True;
                              if Trace_Generate > Extra then
                                 Ada.Text_IO.Put_Line (Trimmed_Image (ID) & " " & Image (ID, Descriptor) & " compute");
                              end if;
                              Terminal_Sequence
                                (Grammar, Descriptor, All_Sequences, All_Set, RHS_Set, Recursing, Recursing_Index, ID);
                              Recursing (ID) := False;

                              if All_Set (ID) or else (for some RHS of RHS_Set (ID) => RHS) then
                                 --  Found a minimal sequence for ID; use it
                                 null;
                              else
                                 All_Sequences (Nonterm)(RHS).Sequence.Clear;
                                 goto Skip;
                              end if;
                           end if;
                        end if;
                        declare
                           Min_RHS : constant Integer := Min (All_Sequences (ID), RHS_Set (ID));
                        begin
                           All_Sequences (Nonterm)(RHS).Sequence.Append (All_Sequences (ID)(Min_RHS).Sequence);
                        end;
                     end if;
                  end;
               end loop;
               RHS_Set (Nonterm)(RHS) := True;
               if Trace_Generate > Extra then
                  Ada.Text_IO.Put_Line
                    (Trimmed_Image (Production_ID'(Nonterm, RHS)) & " => " &
                       Image (All_Sequences (Nonterm)(RHS), Descriptor));
               end if;
            end if;
         end if;
         <<Skip>>
         Skipped_Recursive := True;
      end loop;

      if Skipped_Recursive then
         if (for some RHS of RHS_Set (Nonterm) => not RHS) then
            --  Some RHSs are have unresolved recursion; we will
            --  eventually try again when the recursion is resolved.
            if Trace_Generate > Extra then
               Ada.Text_IO.Put_Line
                 (Trimmed_Image (Nonterm) & " " & Image (Nonterm, Descriptor) & " skipped some recursive");
            end if;
            return;
         end if;
      end if;

      All_Set (Nonterm) := True;

      if Trace_Generate > Extra then
         Ada.Text_IO.Put_Line
           (Trimmed_Image (Nonterm) & " " & Image (Nonterm, Descriptor) & " ==> " &
              Image (All_Sequences (Nonterm), Descriptor));
      end if;
   end Terminal_Sequence;

   ----------
   --  Public subprograms, declaration order

   procedure Put
     (Item       : in Conflict_Lists.List;
      File       : in Ada.Text_IO.File_Type;
      Descriptor : in WisiToken.Descriptor)
   is begin
      for Conflict of Item loop
         Ada.Text_IO.Put_Line (File, Image (Conflict, Descriptor));
      end loop;
   end Put;

   procedure Add_Action
     (Symbol               : in     Token_ID;
      Action               : in     Parse_Action_Rec;
      Action_List          : in out Action_Node_Ptr;
      Closure              : in     LR1_Items.Item_Set;
      Grammar              : in     WisiToken.Productions.Prod_Arrays.Vector;
      Has_Empty_Production : in     Token_ID_Set;
      First_Nonterm_Set    : in     Token_Array_Token_Set;
      Conflicts            : in out Conflict_Lists.List;
      Descriptor           : in     WisiToken.Descriptor)
   is
      Matching_Action : constant Action_Node_Ptr := Find (Symbol, Action_List);
   begin
      if Trace_Generate > Outline then
         Ada.Text_IO.Put (Image (Symbol, Descriptor) & " => ");
         Put (Descriptor, Action);
         Ada.Text_IO.New_Line;
      end if;

      if Matching_Action /= null then
         if Equal (Matching_Action.Action.Item, Action) then
            --  Matching_Action is identical to Action, so there is no
            --  conflict; just don't add it again.
            if Trace_Generate > Outline then
               Ada.Text_IO.Put_Line (" - already present");
            end if;
            return;
         else
            --  There is a conflict. Report it and add it, so the
            --  generalized parser can follow both paths
            declare
               --  Enforce canonical Shift/Reduce or Accept/Reduce
               --  order, to simplify searching and code generation.
               Action_A : constant Parse_Action_Rec :=
                 (if Action.Verb in Shift | Accept_It then Action else Matching_Action.Action.Item);

               Action_B : constant Parse_Action_Rec :=
                 (if Action.Verb in Shift | Accept_It then Matching_Action.Action.Item else Action);

               New_Conflict : constant Conflict :=
                 (Action_A    => Action_A.Verb,
                  Action_B    => Action_B.Verb,
                  LHS_A       => Find
                    (Closure, Action_A, Symbol, Grammar, Has_Empty_Production, First_Nonterm_Set, Descriptor),
                  LHS_B       => Find
                    (Closure, Action_B, Symbol, Grammar, Has_Empty_Production, First_Nonterm_Set, Descriptor),
                  State_Index => Closure.State,
                  On          => Symbol);
            begin
               if not Is_Present (New_Conflict, Conflicts) then
                  --  The same conflict may occur in a different
                  --  item set. Only add it to conflicts once.
                  Conflicts.Append (New_Conflict);

                  if Trace_Generate > Outline then
                     Ada.Text_IO.Put_Line (" - conflict added: " & Image (New_Conflict, Descriptor));
                  end if;
               else
                  if Trace_Generate > Outline then
                     Ada.Text_IO.Put_Line (" - conflict duplicate: " & Image (New_Conflict, Descriptor));
                  end if;
               end if;

               --  More than two actions can occur; see triple_conflict.wy. We make
               --  that an error, since the grammar will be better off without them.
               --  But keep going; the full parse table output will be needed to fix
               --  the excess conflict.
               if Matching_Action.Action.Next /= null then
                  if Matching_Action.Action.Item = Action or Matching_Action.Action.Next.Item = Action then
                     if Trace_Generate > Outline then
                        Ada.Text_IO.Put_Line (" - conflict duplicate");
                     end if;
                  else
                     WisiToken.Generate.Put_Error
                       ("More than two actions on " & Image (Symbol, Descriptor) &
                          " in state" & State_Index'Image (Closure.State));
                  end if;
               end if;

               if Action.Verb = Shift then
                  Matching_Action.Action := new Parse_Action_Node'(Action, Matching_Action.Action);
               else
                  Matching_Action.Action.Next := new Parse_Action_Node'(Action, Matching_Action.Action.Next);
               end if;
            end;
         end if;
      else
         WisiToken.Parse.LR.Add (Action_List, Symbol, Action);
      end if;
   end Add_Action;

   procedure Add_Actions
     (Closure              : in     LR1_Items.Item_Set;
      Table                : in out Parse_Table;
      Grammar              : in     WisiToken.Productions.Prod_Arrays.Vector;
      Has_Empty_Production : in     Token_ID_Set;
      First_Nonterm_Set    : in     Token_Array_Token_Set;
      Conflicts            : in out Conflict_Lists.List;
      Descriptor           : in     WisiToken.Descriptor)
   is
      use WisiToken.Token_ID_Arrays;

      State : constant State_Index := Closure.State;
   begin
      if Trace_Generate > Outline then
         Ada.Text_IO.Put_Line ("adding actions for state" & State_Index'Image (State));
      end if;

      for Item of Closure.Set loop
         if Item.Dot = No_Element then
            --  Pointer is at the end of the production; add a reduce action.

            Add_Lookahead_Actions
              (Item, Table.States (State).Action_List, Grammar, Has_Empty_Production, First_Nonterm_Set,
               Conflicts, Closure, Descriptor);

         elsif Element (Item.Dot) in Descriptor.First_Terminal .. Descriptor.Last_Terminal then
            --  Dot is before a terminal token.
            declare
               use all type Ada.Containers.Count_Type;

               Dot_ID : constant Token_ID := Element (Item.Dot);
               --  ID of token after Item.Dot

               Goto_State : constant Unknown_State_Index := LR1_Items.Goto_State (Closure, Dot_ID);
            begin
               if Dot_ID = Descriptor.EOI_ID then
                  --  This is the start symbol production with dot before EOF.
                  declare
                     P_ID : constant Production_ID := Item.Prod;
                     RHS  : Productions.Right_Hand_Side renames Grammar (P_ID.LHS).RHSs (P_ID.RHS);
                  begin
                     Add_Action
                       (Dot_ID,
                        (Accept_It, P_ID, RHS.Action, RHS.Check, RHS.Tokens.Length - 1),
                        --  EOF is not pushed on stack in parser, because the action for EOF
                        --  is Accept, not Shift.
                        Table.States (State).Action_List, Closure,
                        Grammar, Has_Empty_Production, First_Nonterm_Set, Conflicts, Descriptor);
                  end;
               else
                  if Goto_State /= Unknown_State then
                     Add_Action
                       (Dot_ID,
                        (Shift, Goto_State),
                        Table.States (State).Action_List,
                        Closure, Grammar, Has_Empty_Production, First_Nonterm_Set, Conflicts, Descriptor);
                  end if;
               end if;
            end;
         else
            --  Dot is before a non-terminal token; no action.
            if Trace_Generate > Outline then
               Ada.Text_IO.Put_Line (Image (Element (Item.Dot), Descriptor) & " => no action");
            end if;
         end if;
      end loop;

      --  Place a default error action at the end of every state.
      --  (it should always have at least one action already).
      declare
         --  The default action, when nothing else matches an input
         Default_Action : constant Action_Node :=
           --  The symbol here is actually irrelevant; it is the
           --  position as the last on a state's action list that makes
           --  it the default.
           (Symbol => Invalid_Token_ID,
            Action => new Parse_Action_Node'(Parse_Action_Rec'(Verb => WisiToken.Parse.LR.Error), null),
            Next   => null);

         Last_Action : Action_Node_Ptr := Table.States (State).Action_List;
      begin
         if Last_Action = null then
            --  This happens if the first production in the grammar is
            --  not the start symbol production.
            --
            --  It also happens when the start symbol production does
            --  not have an explicit EOF, or when there is more than
            --  one production that has the start symbol on the left
            --  hand side.
            --
            --  It also happens when the grammar is bad, for example:
            --
            --  declarations <= declarations & declaration
            --
            --  without 'declarations <= declaration'.
            --
            --  We continue generating the grammar, in order to help the user
            --  debug this issue.
            WisiToken.Generate.Error := True;

            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Current_Error, "Error: state" & State_Index'Image (State) &
                 " has no actions; bad grammar, or " &
                 "first production in grammar must be the only start symbol production, " &
                 "and it must must have an explicit EOF.");
         else
            while Last_Action.Next /= null loop
               Last_Action := Last_Action.Next;
            end loop;
            Last_Action.Next := new Action_Node'(Default_Action);
         end if;
      end;

      for Item of Closure.Goto_List loop
         if Item.Symbol in Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal then
            Add_Goto (Table.States (State), Item.Symbol, Item.State); -- note list is already sorted.
         end if;
      end loop;
   end Add_Actions;

   procedure Add_Lookahead_Actions
     (Item                 : in     LR1_Items.Item;
      Action_List          : in out Action_Node_Ptr;
      Grammar              : in     WisiToken.Productions.Prod_Arrays.Vector;
      Has_Empty_Production : in     Token_ID_Set;
      First_Nonterm_Set    : in     Token_Array_Token_Set;
      Conflicts            : in out Conflict_Lists.List;
      Closure              : in     LR1_Items.Item_Set;
      Descriptor           : in     WisiToken.Descriptor)
   is
      Prod   : Productions.Instance renames Grammar (Item.Prod.LHS);
      RHS    : Productions.Right_Hand_Side renames Prod.RHSs (Item.Prod.RHS);
      Action : constant Parse_Action_Rec := (Reduce, Item.Prod, RHS.Action, RHS.Check, RHS.Tokens.Length);
   begin
      if Trace_Generate > Outline then
         Ada.Text_IO.Put_Line ("processing lookaheads");
      end if;

      --  We ignore propagate lookaheads here.
      for Lookahead in Item.Lookaheads'Range loop
         if Item.Lookaheads (Lookahead) then
            if Lookahead = Descriptor.First_Nonterminal then
               null;
            else
               Add_Action
                 (Lookahead, Action, Action_List, Closure, Grammar,
                  Has_Empty_Production, First_Nonterm_Set, Conflicts, Descriptor);
            end if;
         end if;
      end loop;
   end Add_Lookahead_Actions;

   procedure Delete_Known
     (Conflicts       : in out Conflict_Lists.List;
      Known_Conflicts : in out Conflict_Lists.List)
   is
      --  Delete all elements in Conflicts that match an element in
      --  Known_Conflicts. There can be more than one Conflict that
      --  match one Known_Conflict.
      use Conflict_Lists;
      Known      : Cursor  := Known_Conflicts.First;
      Next_Known : Cursor;
   begin
      loop
         exit when Known = No_Element;
         Next_Known := Next (Known);
         declare
            I      : Cursor  := Conflicts.First;
            Next_I : Cursor;
            Used   : Boolean := False;
         begin
            loop
               exit when I = No_Element;
               Next_I := Next (I);
               if Match (Element (Known), Conflicts.Constant_Reference (I)) then
                  Delete (Conflicts, I);
                  Used := True;
               end if;
               I := Next_I;
            end loop;

            if Used then
               Delete (Known_Conflicts, Known);
            end if;
         end;
         Known := Next_Known;
      end loop;
   end Delete_Known;

   function Find
     (Closure              : in LR1_Items.Item_Set;
      Action               : in Parse_Action_Rec;
      Lookahead            : in Token_ID;
      Grammar              : in WisiToken.Productions.Prod_Arrays.Vector;
      Has_Empty_Production : in Token_ID_Set;
      First                : in Token_Array_Token_Set;
      Descriptor           : in WisiToken.Descriptor)
     return Token_ID
   is
      use WisiToken.Token_ID_Arrays;

      ID_I : Cursor;
   begin
      case Action.Verb is
      when Reduce | Accept_It =>
         --  If the nonterm produced by the reduce is the LHS of the state
         --  production, use it.
         for Item of Closure.Set loop
            if LR1_Items.In_Kernel (Grammar, Descriptor, Item) and
              Action.Production.LHS = Item.Prod.LHS
            then
               return Item.Prod.LHS;
            end if;
         end loop;

         --  The reduce nonterm is after Dot in a state production; find which
         --  one, use that.
         for Item of Closure.Set loop
            if LR1_Items.In_Kernel (Grammar, Descriptor, Item) then
               ID_I := Item.Dot;
               loop
                  if ID_I = No_Element then
                     if Item.Lookaheads (Lookahead) then
                        return Item.Prod.LHS;
                     end if;
                  else
                     declare
                        Dot_ID : Token_ID renames Element (ID_I);
                     begin
                        if Dot_ID = Lookahead or
                          (Dot_ID in Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal and then
                             First (Dot_ID, Lookahead))
                        then
                           return Item.Prod.LHS;
                        end if;
                        exit when Dot_ID in Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal and then
                          not Has_Empty_Production (Dot_ID);
                     end;
                  end if;

                  exit when ID_I = No_Element;
                  Next (ID_I);
               end loop;
            end if;
         end loop;

      when Shift =>

         for Item of Closure.Set loop
            --  Lookahead (the token shifted) is starting a nonterm in a state
            --  production; it is in First of that nonterm.
            if LR1_Items.In_Kernel (Grammar, Descriptor, Item) then
               ID_I := Item.Dot;
               loop
                  exit when ID_I = No_Element;
                  declare
                     Dot_ID : Token_ID renames Element (ID_I);
                  begin
                     if Dot_ID = Lookahead or
                       (Dot_ID in Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal and then
                          First (Dot_ID, Lookahead))
                     then
                        return Item.Prod.LHS;
                     end if;

                     exit when Dot_ID in Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal and then
                       not Has_Empty_Production (Dot_ID);
                  end;

                  Next (ID_I);
               end loop;
            end if;
         end loop;

      when WisiToken.Parse.LR.Error =>
         raise SAL.Programmer_Error;
      end case;

      Ada.Text_IO.Put_Line
        ("item for " & Image (Action, Descriptor) & " on " & Image (Lookahead, Descriptor) & " not found in");
      LR1_Items.Put (Grammar, Descriptor, Closure, Kernel_Only => True);
      raise SAL.Programmer_Error;
   end Find;

   function Image (Item : in Conflict; Descriptor : in WisiToken.Descriptor) return String
   is begin
      return
        ("%conflict " &
           Conflict_Parse_Actions'Image (Item.Action_A) & "/" &
           Conflict_Parse_Actions'Image (Item.Action_B) & " in state " &
           Image (Item.LHS_A, Descriptor) & ", " &
           Image (Item.LHS_B, Descriptor) &
           " on token " & Image (Item.On, Descriptor) &
           " (" & State_Index'Image (Item.State_Index) & ")"); -- state number last for easier delete
   end Image;

   function Is_Present (Item : in Conflict; Conflicts : in Conflict_Lists.List) return Boolean
   is
      use Conflict_Lists;
      I : Cursor := Conflicts.First;
   begin
      loop
         exit when I = No_Element;
         if Match (Item, Conflicts.Constant_Reference (I)) then
            return True;
         end if;
         I := Next (I);
      end loop;
      return False;
   end Is_Present;

   function Match (Known : in Conflict; Item : in Conflict_Lists.Constant_Reference_Type) return Boolean
   is begin
      --  Ignore State_Index. Actions are in canonical order; enforced
      --  in Add_Action above. For reduce/reduce, LHS_A, LHS_B are not
      --  in canonical order.
      return
        Known.Action_A = Item.Action_A and
        Known.Action_B = Item.Action_B and
        ((Known.LHS_A = Item.LHS_A and Known.LHS_B = Item.LHS_B) or
           (Known.LHS_B = Item.LHS_A and Known.LHS_A = Item.LHS_B)) and
        Known.On = Item.On;
   end Match;

   function Image (Item : in RHS_Sequence; Descriptor : in WisiToken.Descriptor) return String
   is begin
      return "(" & Boolean'Image (Item.Left_Recursive) & ", " & Image (Item.Sequence, Descriptor) & ")";
   end Image;

   function Min (Item : in RHS_Sequence_Arrays.Vector) return RHS_Sequence
   is
      use all type Ada.Containers.Count_Type;
      Min_Length : Ada.Containers.Count_Type := Ada.Containers.Count_Type'Last;
      Min_RHS    : Natural                   := Natural'Last;
   begin
      --  This version assumes all RHS are computed.
      for RHS in Item.First_Index .. Item.Last_Index loop
         if Min_Length > Item (RHS).Sequence.Length then
            Min_Length := Item (RHS).Sequence.Length;
            Min_RHS    := RHS;
         end if;
      end loop;
      if Min_RHS = Natural'Last then
         raise Grammar_Error with "nonterm has no minimum terminal sequence";
      else
         return Item (Min_RHS);
      end if;
   end Min;

   function Compute_Minimal_Terminal_Sequences
     (Descriptor : in     WisiToken.Descriptor;
      Grammar    : in     WisiToken.Productions.Prod_Arrays.Vector)
     return Minimal_Sequence_Array
   is
      --  Result (ID).Length = 0 is a valid sequence (ie the nonterminal can
      --  be empty), so we use an auxilliary array to track whether Result
      --  (ID) has been computed.
      --
      --  We also need to detect mutual recursion, and incomplete grammars.

      All_Set   : Token_ID_Set := (Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal  => False);
      Recursing : Token_ID_Set := (Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal  => False);

      Recursing_Index : Token_ID_Array_Positive :=
        (Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal  => Positive'Last);

      RHS_Set : Token_ID_RHS_Set :=
        (Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal => LR.RHS_Set.Empty_Vector);

      Last_Count : Integer := 0;
      This_Count : Integer;
   begin
      return Result : Minimal_Sequence_Array (Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal) do
         loop
            exit when (for all B of All_Set => B);
            for P of Grammar loop
               if not All_Set (P.LHS) then
                  Terminal_Sequence (Grammar, Descriptor, Result, All_Set, RHS_Set, Recursing, Recursing_Index, P.LHS);
               end if;
            end loop;
            This_Count := Count (All_Set);
            if This_Count = Last_Count then
               Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Image (All_Set, Descriptor, Inverted => True));
               raise Grammar_Error with "recursion not resolved";
            end if;
            Last_Count := This_Count;
         end loop;
      end return;
   end Compute_Minimal_Terminal_Sequences;

   function Compute_Minimal_Terminal_First
     (Descriptor                 : in WisiToken.Descriptor;
      Minimal_Terminal_Sequences : in Minimal_Sequence_Array)
     return Token_Array_Token_ID
   is
      use all type Ada.Containers.Count_Type;
      use Token_ID_Arrays;
   begin
      return Result : Token_Array_Token_ID (Descriptor.First_Nonterminal .. Descriptor.Last_Nonterminal) do
         for ID in Result'Range loop
            declare
               Min_Seq : Token_ID_Arrays.Vector renames Min (Minimal_Terminal_Sequences (ID)).Sequence;
            begin
               if Min_Seq.Length = 0 then
                  Result (ID) := Invalid_Token_ID;
               else
                  Result (ID) := Element (Min_Seq.First);
               end if;
            end;
         end loop;
      end return;
   end Compute_Minimal_Terminal_First;

   procedure Set_Minimal_Complete_Actions
     (State                      : in out Parse_State;
      Kernel                     : in     LR1_Items.Item_Set;
      Descriptor                 : in     WisiToken.Descriptor;
      Grammar                    : in     WisiToken.Productions.Prod_Arrays.Vector;
      Minimal_Terminal_Sequences : in     Minimal_Sequence_Array;
      Minimal_Terminal_First     : in     Token_Array_Token_ID)
   is
      use all type Ada.Containers.Count_Type;
      use LR1_Items.Item_Lists;
      use Token_ID_Arrays;

      subtype Terminals is Token_ID range Descriptor.First_Terminal .. Descriptor.Last_Terminal;

      Working_Set : LR1_Items.Item_Lists.List := Kernel.Set;
      Del         : LR1_Items.Item_Lists.Cursor;

      function Find_Action (List : in Action_Node_Ptr; ID : in Token_ID) return Minimal_Action
      is
         Node : Action_Node_Ptr := List;
      begin
         loop
            if Node.Symbol = ID then
               case Node.Action.Item.Verb is
               when Shift =>
                  return (Shift, ID, Node.Action.Item.State);
               when Reduce =>
                  --  Item.Dot is a nonterm that starts with a nullable nonterm; reduce
                  --  to that first.
                  return (Reduce, Node.Action.Item.Production.LHS, 0);
               when Accept_It | WisiToken.Parse.LR.Error =>
                  raise SAL.Programmer_Error;
               end case;
            end if;
            Node := Node.Next;
            exit when Node = null;
         end loop;
         raise SAL.Programmer_Error;
      end Find_Action;

      procedure Delete_Non_Minimal
      is
         Min_Length : Ada.Containers.Count_Type := Ada.Containers.Count_Type'Last;
         I          : LR1_Items.Item_Lists.Cursor;
         Min_I      : LR1_Items.Item_Lists.Cursor;
      begin
         --  The absolute minimal production for an LHS may not be in this state.
         --  For example, for an Ada aggregate, the minimal terminal sequence is:
         --  aggregate <= LEFT_PAREN RIGHT_PAREN
         --  but one state has:
         --  aggregate <= LEFT_PAREN expression_opt WITH ^ NULL RECORD RIGHT_PAREN
         --  aggregate <= LEFT_PAREN expression_opt WITH ^ association_list RIGHT_PAREN
         --
         --  Find the minimum of the productions that are present

         I := Working_Set.First;
         loop
            exit when not Has_Element (I);
            declare
               Prod : constant WisiToken.Production_ID := Constant_Ref (I).Prod;
            begin
               --  IMPROVEME: If Dot is near the end of a production, this is not the
               --  best metric; the best metric is count of remaining tokens to
               --  insert. But changing to that won't make much difference; it only
               --  matters when Dot is not near the beginning, but then we don't have
               --  multiple productions (they all must have same prefix).
               --
               --  We must eliminate direct left recursion; otherwise it can appear
               --  to have a minimum length. For example, consider ada_lite state
               --  149:
               --
               --  57.0:actual_parameter_part <= LEFT_PAREN association_list ^ RIGHT_PAREN
               --  61.0:association_list <= association_list ^ COMMA association_opt
               --
               --  Both have length 2, but the association_list requires a
               --  RIGHT_PAREN eventually.
               --
               --  We also have to eliminate indirect left recursion; consider ada_lite state 60:
               --
               --   94.0:function_specification <= FUNCTION name ^ parameter_and_result_profile
               --  103.0:name <= name ^ LEFT_PAREN range_list
               --  103.1:name <= name ^ actual_parameter_part
               --  123.0:selected_component <= name ^ DOT IDENTIFIER
               --
               --  'selected' component has length 3, which two others also have, but
               --  it requires more eventually.
               --
               --  An item production is left recursive only if Dot is after the
               --  first token (ie, before the second token); consider conflict_name
               --  state 5:
               --
               --   8.0:attribute_reference <= name TICK ^ attribute_designator, RIGHT_PAREN/TICK/Wisi_EOI
               --  11.0:qualified_expression <= name TICK ^ aggregate, RIGHT_PAREN/TICK/Wisi_EOI
               --
               --  Both are indirect left recursive with "name", but both are past
               --  the recursion, and can be completed.

               if Min_Length > Minimal_Terminal_Sequences (Prod.LHS)(Prod.RHS).Sequence.Length and
                 not (Minimal_Terminal_Sequences (Prod.LHS)(Prod.RHS).Left_Recursive and then
                        (Has_Element (Constant_Ref (I).Dot) and then
                           Constant_Ref (I).Dot = To_Cursor (Grammar (Prod.LHS).RHSs (Prod.RHS).Tokens, 2)))
               then
                  Min_Length := Minimal_Terminal_Sequences (Prod.LHS)(Prod.RHS).Sequence.Length;
                  Min_I      := I;
               end if;
            end;
            Next (I);
         end loop;

         if not Has_Element (Min_I) then
            Working_Set.Clear;
         else
            I := Working_Set.First;
            loop
               exit when not Has_Element (I);
               declare
                  Prod : constant WisiToken.Production_ID := Constant_Ref (I).Prod;
               begin
                  if I /= Min_I then
                     if Trace_Generate > Extra then
                        Ada.Text_IO.Put_Line ("delete " & Image (Prod) & " not minimal");
                     end if;
                     Del := I;
                     Next (I);
                     Working_Set.Delete (Del);
                  else
                     Next (I);
                  end if;
               end;
            end loop;
         end if;
      end Delete_Non_Minimal;

   begin
      --  The actions computed here are used in the error recovery
      --  algorithm, to decide what terminals to insert in the input stream
      --  in order to correct an error. The strategy is to complete a high
      --  level production (ie declaration or statement) as quickly as
      --  possible, because the next real token is known to be the start of
      --  a high level production, or the end of a containing block-style
      --  production.
      --
      --  The actions are empty in a state that includes the accept
      --  production, or where the only not left recursive productions can
      --  be empty. That tells the error recovery algorithm to stop using
      --  the minimal complete actions strategy.

      if (for some Item of Working_Set =>
            Item.Prod.LHS = Descriptor.Accept_ID and
            (Has_Element (Item.Dot) and then Element (Item.Dot) = Descriptor.EOI_ID))
      then
         --  No actions
         return;
      end if;

      if Working_Set.Length > 1 then
         --  There are multiple productions in this state, all equally valid;
         --  the choice is determined by what input error recovery inserts.
         Delete_Non_Minimal;
      end if;

      if Trace_Generate > Extra then
         Ada.Text_IO.Put_Line ("after deletions:");
         LR1_Items.Put (Grammar, Descriptor, Working_Set, Show_Lookaheads => False);
      end if;

      --  Find the actions for the remaining productions.

      for Item of Working_Set loop
         if not Has_Element (Item.Dot) then
            --  Item has no next terminal. Include a reduce action; the
            --  Minimal_Terminal_First for the resulting state will be used.
            if Trace_Generate > Extra then
               Ada.Text_IO.Put_Line ("reduce " & Image (Item.Prod));
            end if;
            State.Minimal_Complete_Action :=
              (Reduce, Item.Prod.LHS,
                Token_Count => Grammar (Item.Prod.LHS).RHSs (Item.Prod.RHS).Tokens.Length);
         else
            declare
               ID : constant Token_ID := Element (Item.Dot);
            begin
               if ID /= Descriptor.EOI_ID then

                  if ID in Terminals then
                     State.Minimal_Complete_Action := Find_Action (State.Action_List, ID);

                  else
                     if Minimal_Terminal_First (ID) = Invalid_Token_ID then
                        --  Item.Dot is a nullable nonterm, include a reduce of the null
                        --  nonterm, rather than a shift of the following terminal; recover
                        --  must do the reduce first.
                        State.Minimal_Complete_Action := (Reduce, ID, Token_Count => 0);

                     else
                        State.Minimal_Complete_Action := Find_Action (State.Action_List, Minimal_Terminal_First (ID));
                     end if;
                  end if;
               end if;
            end;
         end if;
      end loop;
   end Set_Minimal_Complete_Actions;

   ----------
   --  Parse table output

   procedure Put_Text_Rep
     (Table        : in Parse_Table;
      File_Name    : in String;
      Action_Names : in Names_Array_Array;
      Check_Names  : in Names_Array_Array)
   is
      use Ada.Text_IO;
      File : File_Type;
   begin
      --  Only space, semicolon, newline delimit object values. Bounds of
      --  arrays output before each array, unless known from discriminants.
      --  End of lists indicated by semicolon. Action, Check subprograms are
      --  represented by True if present, False if not; look up the actual
      --  address Table.Productions.

      Create (File, Out_File, File_Name);

      --  First the discriminants
      Put (File,
           Trimmed_Image (Table.State_First) & State_Index'Image (Table.State_Last) &
             Token_ID'Image (Table.First_Terminal) & Token_ID'Image (Table.Last_Terminal) &
             Token_ID'Image (Table.First_Nonterminal) & Token_ID'Image (Table.Last_Nonterminal));
      New_Line (File);

      for State of Table.States loop
         Put (File, Integer'Image (State.Productions.First_Index));
         Put (File, Integer'Image (State.Productions.Last_Index));
         for Prod of State.Productions loop
            Put (File, Token_ID'Image (Prod.LHS) & Integer'Image (Prod.RHS));
         end loop;
         New_Line (File);

         declare
            Node_I : Action_Node_Ptr := State.Action_List;
         begin
            loop
               exit when Node_I = null;
               --  Action first, so we know if Symbol is present (not when Error)
               declare
                  Node_J     : Parse_Action_Node_Ptr := Node_I.Action;
                  Put_Symbol : Boolean               := True;
               begin
                  loop
                     Put (File, Parse_Action_Verbs'Image (Node_J.Item.Verb));

                     case Node_J.Item.Verb is
                     when Shift =>
                        Put (File, State_Index'Image (Node_J.Item.State));

                     when Reduce | Accept_It =>
                        Put (File, Token_ID'Image (Node_J.Item.Production.LHS) &
                               Integer'Image (Node_J.Item.Production.RHS));

                        if Action_Names (Node_J.Item.Production.LHS) /= null and then
                          Action_Names (Node_J.Item.Production.LHS)(Node_J.Item.Production.RHS) /= null
                        then
                           Put (File, " true");
                        else
                           Put (File, " false");
                        end if;
                        if Check_Names (Node_J.Item.Production.LHS) /= null and then
                          Check_Names (Node_J.Item.Production.LHS)(Node_J.Item.Production.RHS) /= null
                        then
                           Put (File, " true");
                        else
                           Put (File, " false");
                        end if;

                        Put (File, Ada.Containers.Count_Type'Image (Node_J.Item.Token_Count));

                     when Parse.LR.Error =>
                        --  Error action terminates the action list
                        Put_Symbol := False;
                     end case;

                     Node_J := Node_J.Next;
                     exit when Node_J = null;
                     Put (File, ' ');
                  end loop;
                  Put (File, ';');
                  if Put_Symbol then
                     Put (File, Token_ID'Image (Node_I.Symbol));
                  end if;
               end;
               New_Line (File);

               Node_I := Node_I.Next;
            end loop;
         end;

         declare
            Node_I : Goto_Node_Ptr := State.Goto_List;
         begin
            loop
               exit when Node_I = null;
               Put (File, Token_ID'Image (Symbol (Node_I)) & State_Index'Image (Parse.LR.State (Node_I)));
               Node_I := Next (Node_I);
            end loop;
            Put (File, ';');
            New_Line (File);
         end;

         declare
            Action  : Minimal_Action renames State.Minimal_Complete_Action;
         begin
            case State.Minimal_Complete_Action.Verb is
            when Pause =>
               null;
            when Shift =>
               Put (File, Minimal_Verbs'Image (Action.Verb));
               Put (File, Token_ID'Image (Action.ID) & State_Index'Image (Action.State));
            when Reduce =>
               Put (File, Minimal_Verbs'Image (Action.Verb));
               Put (File, Token_ID'Image (Action.Nonterm) & Ada.Containers.Count_Type'Image (Action.Token_Count));
            end case;
         end;
         Put (File, ';');
         New_Line (File);
      end loop;
      Close (File);
   end Put_Text_Rep;

   procedure Put (Item : in Parse_Action_Rec; Descriptor : in WisiToken.Descriptor)
   is
      use Ada.Containers;
      use Ada.Text_IO;
   begin
      case Item.Verb is
      when Shift =>
         Put ("shift and goto state" & State_Index'Image (Item.State));

      when Reduce =>
         Put
           ("reduce" & Count_Type'Image (Item.Token_Count) & " tokens to " &
              Image (Item.Production.LHS, Descriptor));
      when Accept_It =>
         Put ("accept it");
      when Parse.LR.Error =>
         Put ("ERROR");
      end case;
   end Put;

   procedure Put (Item : in McKenzie_Param_Type; Descriptor : in WisiToken.Descriptor)
   is
      use Ada.Text_IO;
   begin
      Put_Line ("(Insert =>");
      for I in Item.Insert'Range loop
         Put (" " & Padded_Image (I, Descriptor) & " =>" & Natural'Image (Item.Insert (I)));
         if I = Item.Insert'Last then
            Put_Line (")");
         else
            Put_Line (",");
         end if;
      end loop;
      Put_Line ("(Delete =>");
      for I in Item.Delete'Range loop
         Put (" " & Padded_Image (I, Descriptor) & " =>" & Natural'Image (Item.Delete (I)));
         if I = Item.Delete'Last then
            Put_Line (")");
         else
            Put_Line (",");
         end if;
      end loop;
      Put_Line ("(Push_Back =>");
      for I in Item.Delete'Range loop
         Put (" " & Padded_Image (I, Descriptor) & " =>" & Natural'Image (Item.Delete (I)));
         if I = Item.Delete'Last then
            Put_Line (")");
         else
            Put_Line (",");
         end if;
      end loop;
      Put_Line ("Ignore_Check_Fail =>" & Integer'Image (Item.Ignore_Check_Fail));
      Put_Line ("Task_Count        =>" & System.Multiprocessors.CPU_Range'Image (Item.Task_Count));
      Put_Line ("Cost_Limit        =>" & Integer'Image (Item.Cost_Limit));
      Put_Line ("Check_Limit       =>" & Token_Index'Image (Item.Check_Limit));
      Put_Line ("Check_Delta_Limit =>" & Integer'Image (Item.Check_Delta_Limit));
      Put_Line ("Enqueue_Limit     =>" & Integer'Image (Item.Enqueue_Limit));
   end Put;

   procedure Put (Descriptor : in WisiToken.Descriptor; Item : in Parse_Action_Rec)
   is
      use Ada.Containers;
      use Ada.Text_IO;
   begin
      case Item.Verb is
      when Shift =>
         Put ("shift and goto state" & State_Index'Image (Item.State));
      when Reduce =>
         Put
           ("reduce" & Count_Type'Image (Item.Token_Count) & " tokens to " &
              Image (Item.Production.LHS, Descriptor));
         Put (" " & Trimmed_Image (Item.Production));
      when Accept_It =>
         Put ("accept it");
         Put (" " & Trimmed_Image (Item.Production));
      when Parse.LR.Error =>
         Put ("ERROR");
      end case;
   end Put;

   procedure Put (Descriptor : in WisiToken.Descriptor; Action : in Parse_Action_Node_Ptr)
   is
      use Ada.Text_IO;
      Ptr    : Parse_Action_Node_Ptr   := Action;
      Column : constant Positive_Count := Col;
   begin
      loop
         Put (Descriptor, Ptr.Item);
         Ptr := Ptr.Next;
         exit when Ptr = null;
         Put_Line (",");
         Set_Col (Column);
      end loop;
   end Put;

   procedure Put (Descriptor : in WisiToken.Descriptor; State : in Parse_State)
   is
      use Ada.Text_IO;
      use Ada.Strings.Fixed;
      Action_Ptr : Action_Node_Ptr := State.Action_List;
      Goto_Ptr   : Goto_Node_Ptr   := State.Goto_List;
   begin
      while Action_Ptr /= null loop
         Put ("   ");
         if Action_Ptr.Next = null then
            Put ("default" & (Descriptor.Image_Width - 7) * ' ' & " => ");

         elsif Action_Ptr.Action.Item.Verb /= Parse.LR.Error then
            Put (Image (Action_Ptr.Symbol, Descriptor) &
                   (Descriptor.Image_Width - Image (Action_Ptr.Symbol, Descriptor)'Length) * ' '
                   & " => ");
         end if;
         Put (Descriptor, Action_Ptr.Action);
         New_Line;
         Action_Ptr := Action_Ptr.Next;
      end loop;

      if Goto_Ptr /= null then
         New_Line;
      end if;

      while Goto_Ptr /= null loop
         Put_Line
           ("   " & Image (Symbol (Goto_Ptr), Descriptor) &
              (Descriptor.Image_Width - Image (Symbol (Goto_Ptr), Descriptor)'Length) * ' ' &
              " goto state" & State_Index'Image (Parse.LR.State (Goto_Ptr)));
         Goto_Ptr := Next (Goto_Ptr);
      end loop;

      New_Line;
      Put ("   Minimal_Complete_Action => (");
      case State.Minimal_Complete_Action.Verb is
      when Pause =>
         null;
      when Shift =>
         Put (Image (State.Minimal_Complete_Action.ID, Descriptor));
      when Reduce =>
         Put (Image (State.Minimal_Complete_Action.Nonterm, Descriptor));
      end case;
      Put_Line (")");
   end Put;

   procedure Put_Parse_Table
     (Table      : in Parse_Table_Ptr;
      Title      : in String;
      Grammar    : in WisiToken.Productions.Prod_Arrays.Vector;
      Kernels    : in LR1_Items.Item_Set_List;
      Conflicts  : in Conflict_Lists.List;
      Descriptor : in WisiToken.Descriptor)
   is
      use all type Ada.Containers.Count_Type;
      use Ada.Text_IO;
   begin
      Put_Line ("Tokens:");
      WisiToken.Put_Tokens (Descriptor);

      New_Line;
      Put_Line ("Productions:");
      WisiToken.Productions.Put (Grammar, Descriptor);

      if Table.McKenzie_Param.Cost_Limit /= Default_McKenzie_Param.Cost_Limit or
          Table.McKenzie_Param.Check_Limit /= Default_McKenzie_Param.Check_Limit or
          Table.McKenzie_Param.Check_Delta_Limit /= Default_McKenzie_Param.Check_Delta_Limit or
          Table.McKenzie_Param.Enqueue_Limit /= Default_McKenzie_Param.Enqueue_Limit
      then
         New_Line;
         Put_Line ("McKenzie:");
         Put (Table.McKenzie_Param, Descriptor);
      end if;

      New_Line;
      Put_Line (Title & " Parse Table:");

      for State_Index in Table.States'Range loop
         LR1_Items.Put (Grammar, Descriptor, Kernels (State_Index), Kernel_Only => True, Show_Lookaheads => True);
         New_Line;
         Put (Descriptor, Table.States (State_Index));

         if State_Index /= Table.States'Last then
            New_Line;
         end if;
      end loop;

      if Conflicts.Length > 0 then
         declare
            use Ada.Strings.Unbounded;
            Last_State : Unknown_State_Index := Unknown_State;
            Line : Unbounded_String := +"States with conflicts:";
         begin
            for Conflict of Conflicts loop
               if Conflict.State_Index /= Last_State then
                  Append (Line, State_Index'Image (Conflict.State_Index));
                  Last_State := Conflict.State_Index;
               end if;
            end loop;
            Indent_Wrap (-Line);
         end;
      end if;
   end Put_Parse_Table;

end WisiToken.Generate.LR;