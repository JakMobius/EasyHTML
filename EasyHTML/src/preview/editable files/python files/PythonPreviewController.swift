////
////  PythonPreviewController.swift
////  EasyHTML
////
////  Created by Артем on 11/04/2019.
////  Copyright © 2019 Артем. All rights reserved.
////
//
//import UIKit
//import SwiftPython3
//
//class PythonPreviewController: UIViewController {
//
//    static var _pythonInitialised = false
//
//    static func initPythonIfNecessary() {
//        if _pythonInitialised {
//            return
//        }
//
//        _pythonInitialised = true
//
//        putenv(strdup("PYTHONOPTIMIZE=2"));
//        putenv(strdup("PYTHONDONTWRITEBYTECODE=1"));
//        putenv(strdup("PYTHONNOUSERSITE=1"));
//        putenv(strdup("PYTHONUNBUFFERED=1)"));
//
//        let resourcePath = applicationPath + "/python-runtime"
//        let fs = FileManager.default
//
//        if !fs.fileExists(atPath: resourcePath) {
//            try! fs.copyItem(
//                at: Bundle.main.resourceURL!.appendingPathComponent("python-runtime"),
//                to: URL(fileURLWithPath: resourcePath)
//            )
//        }
//
//        putenv(strdup("PYTHONHOME=\(resourcePath)"))
//        putenv(strdup("PYTHONPATH=\(resourcePath):\(resourcePath)/lib/python2.7/:\(resourcePath)/lib/python2.7/site-packages"))
//        putenv(strdup("TMP=\(resourcePath)/tmp"))
//
//        PyImport_AppendInittab(strdup("consolemodule"), {
//            () -> UnsafeMutablePointer<PyObject>? in
//            let moduleMethods = [
//                PyMethodDef(ml_name: strdup("out"), ml_meth: {
//                    (obj: UnsafeMutablePointer<PyObject>?, args: UnsafeMutablePointer<PyObject>?) -> UnsafeMutablePointer<PyObject>? in
//
//                    print(obj, args)
//
//                    return nil
//                }, ml_flags: METH_VARARGS, ml_doc: strdup("")),
//                PyMethodDef(ml_name: nil, ml_meth: nil, ml_flags: 0, ml_doc: nil)
//            ]
//
//            var moduleDef = PyModuleDef(
//                m_base: PyModuleDef_Base(
//                    ob_base: PyObject(
//                        ob_refcnt: 1,
//                        ob_type: nil
//                    ),
//                    m_init: nil,
//                    m_index: 0,
//                    m_copy: nil
//                ),
//                m_name: strdup("consolemodule"),
//                m_doc: nil,
//                m_size: -1,
//                m_methods: UnsafeMutablePointer(mutating: moduleMethods),
//                m_slots: nil,
//                m_traverse: nil,
//                m_clear: nil,
//                m_free: nil
//            )
//
//            let module = PyModule_Create2(&moduleDef, PYTHON_API_VERSION)
//
//            return module
//        })
//
//        PyEval_InitThreads()
//        Py_Initialize()
//        PyImport_ImportModule("consolemodule");
//
//    }
//
//    func setupInterpreter() {
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//        let _main = PyThreadState_Get()
//
//        self.interpreter = Py_NewInterpreter()!.pointee
//
//        PyThreadState_Swap(_main)
//
//        pythonEval { (_) in
//            PyRun_SimpleStringFlags(strdup("""
//            import sys
//            import consolemodule
//
//            class StdoutCatcher:
//               def write(self, stuff):
//                  consolemodule.out(stuff)
//
//            sys.stdout = StdoutCatcher()
//            """), nil)
//        }
//    }
//
//    var interpreter: PyThreadState!
//    var file: FSNode.File!
//
//    func navigatedToPreview() {
//        if firstAppear {
//            firstAppear = false
//
//            run()
//        }
//    }
//
//    func pythonEval(operation: (PyThreadState) throws -> ()) rethrows
//    {
//        // acquire the GIL
//
//        var _save = PyEval_SaveThread();
//        var gstate = PyGILState_Ensure();
//
//        // create a new thread state for the the sub interpreter interp
//        var ts = PyThreadState_New(interpreter.interp);
//
//        // make ts the current thread state
//
//        PyThreadState_Swap(ts);
//        do {
//            defer {
//
//                // release ts
//                //
//
//                PyThreadState_Swap(_save);
//                PyGILState_Release(gstate);
//
//                // clear and delete ts
//                PyThreadState_Clear(ts);
//                PyThreadState_Delete(ts);
//
//                // release the GIL
//                PyEval_RestoreThread(_save)
//            }
//
//            // at this point:
//            // 1. You have the GIL
//            // 2. You have the right thread state - a new thread state (this thread was not created by python) in the context of interp
//
//            // PYTHON WORK HERE
//
//            try operation(ts!.pointee)
//
//        } catch {
//            throw error
//        }
//    }
//
//    override func viewDidLoad() {
//        PythonPreviewController.initPythonIfNecessary()
//        setupInterpreter()
//    }
//
//    var firstAppear = true
//
//    func run() {
//
//        guard file.sourceType == .local else { return }
//
//        pythonEval {
//            _ in
//            let file = fopen(strdup(self.file.url.path), strdup("r"))
//
//            PyRun_SimpleFileExFlags(file, strdup(self.file.url.lastPathComponent), 1, nil)
//        }
//    }
//
//    deinit {
//        PyThreadState_Swap(&interpreter)
//        Py_EndInterpreter(&interpreter)
//    }
//}
