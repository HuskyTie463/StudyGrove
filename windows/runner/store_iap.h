#ifndef RUNNER_STORE_IAP_H_
#define RUNNER_STORE_IAP_H_

#include <flutter/binary_messenger.h>

#include <memory>
#include <windows.h>

// Microsoft Store add-on IAP via WinRT StoreContext.
// Queries Partner Center identity studygrove_pro_monthly.
class StoreIapBridge {
 public:
  StoreIapBridge(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~StoreIapBridge();

  StoreIapBridge(const StoreIapBridge&) = delete;
  StoreIapBridge& operator=(const StoreIapBridge&) = delete;

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_STORE_IAP_H_
