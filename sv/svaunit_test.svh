/******************************************************************************
 * (C) Copyright 2015 AMIQ Consulting
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * MODULE:       svaunit_test.svh
 * PROJECT:      svaunit
 * Description:  svaunit test class
 *******************************************************************************/

`ifndef SVAUNIT_TEST_SVH
`define SVAUNIT_TEST_SVH

// svaunit test class
class svaunit_test extends svaunit_base;
   `uvm_component_utils(svaunit_test)

   // Timeout variable - the test will finished if time reaches this timeout
   local time timeout;

   // Virtual sequencer
   svaunit_sequencer sequencer;

   /* Constructor for svaunit_test
    * @param name   : instance name for svaunit_test object
    * @param parent : hierarchical parent for svaunit_test
    */
   function new(string name = "svaunit_test", uvm_component parent);
      super.new(name, parent);
      timeout = 10us;
   endfunction

   /* Build phase method used to instantiate components
    * @param phase : the phase scheduled for build_phase method
    */
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      sequencer = svaunit_sequencer::type_id::create("sequencer", this);

      set_name_for_test();
   endfunction

   /* Compute the fact that the test was started from a test suite or not
    * @return 1 if the test was started from a test suite, 0 otherwise
    */
   virtual function bit was_started_from_test_suite();
      // Get parent of this test
      uvm_component parent = get_parent();

      // Verify if the test was started from a test suite,
      //  the run index for sequences will be the same as the registered one
      if((!started()) && (parent.get_name() == "")) begin
         return 0;
      end else begin
         return 1;
      end
   endfunction

   // Update the test's status according to the number of failed assertions
   virtual function void update_status();
      // Stored how many times the immediate assertion which were exercised passed
      int unsigned nof_times_check_passed = 0;

      // Stored how many times the immediate assertion were exercised
      int unsigned nof_times_check_tested = 0;

      // Stored the name of immediate assertions that were used
      string checks_names[$];
      get_checks_names(checks_names);

      // Compute how many immediate assertion passed and how many were exercised
      foreach(checks_names[index]) begin
         string crt_check_name = checks_names[index];

         foreach(lof_checks[check_index]) begin
            foreach(lof_checks[check_index].checks_details[details_index])begin
               if(lof_checks[check_index].checks_details[details_index].get_check_name() == checks_names[index]) begin
                  nof_times_check_tested = nof_times_check_tested + get_nof_times_check_was_tested(crt_check_name);
                  nof_times_check_passed = nof_times_check_passed + get_nof_times_check_has_passed(crt_check_name);
               end
            end
         end
      end

      // Update nof_tests and nof_failures fields properly
      set_nof_tests(nof_times_check_tested);
      set_nof_failures(nof_times_check_tested - nof_times_check_passed);
 
      // Update status for SVA coverage
      vpiw.update_coverage();

      set_status(compute_status(get_nof_tests(), get_nof_failures()));
   endfunction

   // Enable test to be tested
   virtual function void enable_test();
      enable = 1;
   endfunction

   // Disable test to be tested
   virtual function void disable_test();
      enable = 0;
   endfunction

   // {{{ Functions used for immediate assertions

   /* Get a list with all immediate assertions tested into tests
    * @param a_checks : a list with all immediate assertions tested
    */
   virtual function void get_checks(ref svaunit_immediate_assertion_info a_checks[$]);
      if(sequence_name.size() > 0) begin
         // The test starts sequences
         foreach(sequence_name[index]) begin
            vpiw.get_checks_for_test(sequence_name[index], a_checks);
         end
      end else begin
         // There were no sequences started from this test - it is a simple test
         vpiw.get_checks_for_test(get_test_name(), a_checks);
      end
   endfunction

   /* Get a list with names for all immediate assertion used
    * @param a_lof_used_checks : the string list which contains the name of the checks used in this unit test
    */
   virtual function void get_checks_names(ref string a_lof_used_checks[$]);
      // Iterate all over the immediate assertions to get the checks name
      foreach(lof_checks[check_index]) begin
         lof_checks[check_index].get_checks_names(a_lof_used_checks);
      end
   endfunction

   /* Get immediate assertions from all tests
    * @return the total number of immediate assertions
    */
   virtual function int unsigned get_nof_checks();
      return lof_checks.size();
   endfunction

   /* Get the number of times an SVAUnit check was tested during simulation
    * @param a_check_name : the name of the SVAUnit check
    * @return the number of times an SVAUnit check was tested during simulation
    */
   virtual function int unsigned get_nof_times_check_was_tested(ref string a_check_name);
      // Variable used to store the number of times a check was tested
      int unsigned nof_times_check_tested = 0;

      // Iterate over the check list and it's detail to see if the given check name was tested and
      // increase the number with the proper number of times the check was tested
      foreach(lof_checks[check_index]) begin
         foreach(lof_checks[check_index].checks_details[details_index])begin
            if(lof_checks[check_index].checks_details[details_index].get_check_name() == a_check_name) begin
               nof_times_check_tested = nof_times_check_tested +
               lof_checks[check_index].checks_details[details_index].get_nof_times_check_was_tested();
            end
         end
      end

      return nof_times_check_tested;
   endfunction

   /* Get the number of times an SVAUnit check passed during simulation
    * @param a_check_name : the name of the SVAUnit check
    * @return the number of times an SVAUnit check passed during simulation
    */
   virtual function int unsigned get_nof_times_check_has_passed(ref string a_check_name);
      // Variable used to store the number of times a check has passed
      int unsigned nof_times_check_passed = 0;

      // Iterate over the check list and it's detail to see if the given check name was tested and
      // increase the number with the proper number of times the check has tested
      foreach(lof_checks[check_index]) begin
         foreach(lof_checks[check_index].checks_details[details_index])begin
            if(lof_checks[check_index].checks_details[details_index].get_check_name() == a_check_name) begin
               nof_times_check_passed = nof_times_check_passed +
               lof_checks[check_index].checks_details[details_index].get_nof_times_check_has_passed();
            end
         end
      end

      return nof_times_check_passed;
   endfunction
   // }}}

   // {{{ Functions used to find out SVA properties

   /* Get a list of all SVAs which have the same tested status
    * @param a_sva_tested : a list of all SVAs which have the same tested status
    */
   virtual function void get_sva_tested(ref svaunit_concurrent_assertion_info a_sva_tested[$]);
      if(sequence_name.size() > 0) begin
         // The test starts sequences
         foreach(sequence_name[index]) begin
            vpiw.get_sva_tested(sequence_name[index], a_sva_tested);
         end
      end else begin
         // There were no sequences started from this test - it is a simple test
         vpiw.get_sva_tested(get_test_name(), a_sva_tested);
      end
   endfunction

   /* Get the total number of SVAs
    * @return the total number of SVAs
    */
   virtual function int unsigned get_nof_sva();
      return vpiw.get_nof_sva();
   endfunction

   /* Get the total number of SVAs tested from all tests
    * @return the total number of SVAs tested from all tests
    */
   virtual function int unsigned get_nof_tested_sva();
      return vpiw.get_nof_tested_sva(get_test_name());
   endfunction

   /* Get the names of the SVAs which were tested during test
    * @param a_tested_sva_names : the names of the SVAs which were tested during test
    */
   virtual function void get_sva_tested_names(ref string a_tested_sva_names[$]);
      svaunit_concurrent_assertion_info tested_sva[$];

      // Get all SVA tested
      get_sva_tested(tested_sva);

      vpiw.get_sva_tested_names(tested_sva, a_tested_sva_names);
   endfunction

   /* Get the names of the SVAs which were not tested during test
    * @param a_sva_not_tested : the names of the SVAs which were not tested during test
    */
   virtual function void get_sva_not_tested_names(ref string a_sva_not_tested[$]);
      svaunit_concurrent_assertion_info not_tested_sva[$];

      // Get all SVA tested
      get_sva_not_tested(not_tested_sva);

      vpiw.get_sva_not_tested_names(not_tested_sva, a_sva_not_tested);
   endfunction

   /* Get all SVA from all tests which have not been tested
    * @param a_sva_not_tested : list of all SVAs which have not been tested
    */
   virtual function void get_sva_not_tested(ref svaunit_concurrent_assertion_info a_sva_not_tested[$]);
      if(sequence_name.size() > 0) begin
         // The test starts sequences
         foreach(sequence_name[index]) begin
            vpiw.get_sva_not_tested(sequence_name[index], a_sva_not_tested);
         end
      end else begin
         // There were no sequences started from this test - it is a simple test
         vpiw.get_sva_not_tested(get_test_name(), a_sva_not_tested);
      end
   endfunction
   // }}}

   // {{{ Running tasks

   // Task used to start testing - The user should create here scenarios to verify SVAs
   virtual task test();
   endtask

   /* Set test name for VPI wrapper
    * @param a_test_name : the test name to be added for VPI wrapper
    */
   virtual function void set_test_name_vpi(string a_test_name);
      vpiw.set_test_name_vpi(a_test_name);
   endfunction

   // Will start the unit test and will start the timeout mechanism
   virtual task start_ut();
      if(enable == 1) begin
         start_test();
         set_test_name_vpi(get_test_name());
         vpiw.stop_test = 0;

         fork
            begin
               // Variable used to store the process id for test task
               process simulate_test;
               fork
                  begin
                     simulate_test = process::self();
                     fork
                        begin
                           test();

                           vpiw.pass_assertion();
                        end
                        begin
                           int unsigned time_left = timeout;
                           while(time_left != 0) begin
                              #1ns;
                              time_left = time_left - 1;
                           end
                           `uvm_error("SVAUNIT_TIMEOUT_ERR", "Max simulation timeout reached!")
                        end
                        begin
                           while(stop_test == 0) begin
                              #1ns;

                              stop_test = vpiw.stop_test;
                           end
                        end
                     join_any
                  end
               join
               disable fork;
               simulate_test.kill();
            end
         join

         // Compact immediate assertions
         get_checks(lof_checks);

         // Update status
         update_status();
      end
   endtask

   /* Run phase method used to run test - it will be started only when simulate a single test
    * @param phase : the phase scheduled for run_phase method
    */
   virtual task run_phase(uvm_phase phase);
      // If the test isn't started from a test suite, it should start from here
      if(was_started_from_test_suite() == 0) begin
         // Raise objection mechanism for this test
         uvm_test_done.raise_objection(this, "", 1);

         // Set start test, run test and after that print report
         if(enable == 1) begin
            fork
               begin
                  // Variable used to store the process id for start_up task
                  process start_ut_p;
                  fork
                     begin
                        start_ut_p = process::self();
                        start_ut();
                        disable fork;
                     end
                  join
                  start_ut_p.kill();
               end
            join
            print_report();
         end

         // Drop objection mechanism for this test
         uvm_test_done.drop_objection(this, "", 1);
      end
   endtask
   // }}}

   // {{{ Print functions

   /* Form the status to be printed
    * @return a string represents the status to be printed
    */
   virtual function void print_status();
      string nice_string = "";

      nice_string = $sformatf("\n\n-------------------- %s : Status statistics --------------------", get_test_name());
      nice_string = $sformatf("%s\n\t%s\n", nice_string, get_status_as_string());

      `uvm_info(get_test_name(), nice_string, UVM_LOW)
   endfunction

   /* Form the status to be printed as a string
    * @return a string represents the status to be printed
    */
   virtual function string get_status_as_string();
      string star = " ";
      svaunit_status_type computed_test_status = get_status();

      if(get_status() == SVAUNIT_FAIL) begin
         star = "*";
      end

      return $sformatf("\n\t%s   %s %s (%0d/%0d assertions PASSED)", star, get_test_name(), computed_test_status.name(),
         get_nof_tests() - get_nof_failures(), get_nof_tests());
   endfunction

   /* Form the status of the test as a string
    * @return a string which contains the status of test
    */
   virtual function string get_status_tests();
      return get_status_as_string();
   endfunction

   /* Get a string with all checks used to verify SVAs
    * @return a string represents the checks tested for SVAs
    */
   virtual function string get_checks_for_sva();
      string nice_string = "";

      foreach(lof_checks[check_index]) begin
         nice_string = $sformatf("%s\n\t%s", nice_string, lof_checks[check_index].get_checks_for_sva());
      end

      nice_string = $sformatf("%s", nice_string);
      return nice_string;
   endfunction

   /* Form the test topology as a tree
    * @param a_level : the level where the test is created
    * @return a string representing the tree
    */
   virtual function string form_tree(int a_level);
      string extra = "";
      string nice_string = "";

      for(int level_idx = 0; level_idx < a_level; level_idx++) begin
         extra = {"\t", extra};
      end

      nice_string = $sformatf("%s%s%s", nice_string, extra, get_test_name());

      foreach(sequence_name[index]) begin
         extra = "";
         for(int level_idx = 0; level_idx < (a_level + index + 2); level_idx++) begin
            extra = {"\t", extra};
         end

         nice_string = {nice_string, "\n", extra, sequence_name[index]};
      end

      return nice_string;
   endfunction

   /* Will print assertion info for an SVA with a given name
    * @param a_sva_name : assertion name or path to be found in SVA list
    */
   virtual function void print_sva_info(string a_sva_name);
      vpiw.print_sva_info(a_sva_name);
   endfunction
// }}}
endclass

`endif
