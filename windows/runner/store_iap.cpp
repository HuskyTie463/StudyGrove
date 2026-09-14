#include "store_iap.h"

#undef GetCurrentTime

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#undef GetCurrentTime

#include <shobjidl.h>

#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Services.Store.h>

#include <string>
#include <thread>

namespace {

using winrt::Windows::Foundation::AsyncStatus;
using winrt::Windows::Services::Store::StoreAppLicense;
using winrt::Windows::Services::Store::StoreContext;
using winrt::Windows::Services::Store::StoreLicense;
using winrt::Windows::Services::Store::StoreProduct;
using winrt::Windows::Services::Store::StorePurchaseStatus;

// Partner Center add-on identity. Listing Store ID 9PP0RQTCQ47R is not queried
// as the primary key.
constexpr wchar_t kProductIdentity[] = L"studygrove_pro_monthly";
constexpr wchar_t kListingStoreId[] = L"9PP0RQTCQ47R";

std::string ToUtf8(winrt::hstring const& value) {
  if (value.empty()) {
    return {};
  }
  const wchar_t* wide = value.c_str();
  const int size = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0,
                                       nullptr, nullptr);
  if (size <= 1) {
    return {};
  }
  std::string out(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, out.data(), size, nullptr, nullptr);
  return out;
}

bool ContainsMonthlyId(std::string const& value) {
  return value.find("studygrove_pro_monthly") != std::string::npos ||
         value.find("9PP0RQTCQ47R") != std::string::npos;
}

bool IsMonthlyProduct(StoreProduct const& product) {
  return ContainsMonthlyId(ToUtf8(product.InAppOfferToken())) ||
         ContainsMonthlyId(ToUtf8(product.StoreId()));
}

bool IsMonthlyLicense(StoreLicense const& license) {
  return license.IsActive() && ContainsMonthlyId(ToUtf8(license.SkuStoreId()));
}

void BindContextToWindow(StoreContext const& context, HWND hwnd) {
  if (hwnd == nullptr) {
    return;
  }
  auto init = context.try_as<IInitializeWithWindow>();
  if (init) {
    init->Initialize(hwnd);
  }
}

auto ProductKinds() {
  auto kinds = winrt::single_threaded_vector<winrt::hstring>();
  kinds.Append(L"Durable");
  kinds.Append(L"Subscription");
  return kinds;
}

flutter::EncodableMap UnavailableMap(std::string const& message) {
  return flutter::EncodableMap{
      {flutter::EncodableValue("available"), flutter::EncodableValue(false)},
      {flutter::EncodableValue("owned"), flutter::EncodableValue(false)},
      {flutter::EncodableValue("productFound"), flutter::EncodableValue(false)},
      {flutter::EncodableValue("status"), flutter::EncodableValue("unavailable")},
      {flutter::EncodableValue("message"), flutter::EncodableValue(message)},
  };
}

const char kNotListed[] =
    "Pro unlocks after Study Grove is listed in the Microsoft Store. "
    "Purchase will work for Store-installed builds.";

flutter::EncodableMap QueryStore() {
  flutter::EncodableMap map{
      {flutter::EncodableValue("available"), flutter::EncodableValue(false)},
      {flutter::EncodableValue("owned"), flutter::EncodableValue(false)},
      {flutter::EncodableValue("productFound"), flutter::EncodableValue(false)},
  };

  try {
    auto context = StoreContext::GetDefault();
    bool owned = false;
    bool product_found = false;
    bool available = false;
    std::string price;
    std::string title;

    try {
      StoreAppLicense const license = context.GetAppLicenseAsync().get();
      available = true;
      for (auto const& pair : license.AddOnLicenses()) {
        if (IsMonthlyLicense(pair.Value())) {
          owned = true;
          product_found = true;
        }
      }
    } catch (...) {
    }

    try {
      auto kinds = ProductKinds();
      auto ids = winrt::single_threaded_vector<winrt::hstring>();
      ids.Append(kProductIdentity);
      ids.Append(kListingStoreId);
      auto queried =
          context.GetStoreProductsAsync(kinds.GetView(), ids.GetView()).get();
      available = true;
      for (auto const& pair : queried.Products()) {
        StoreProduct const product = pair.Value();
        if (!IsMonthlyProduct(product)) {
          continue;
        }
        product_found = true;
        title = ToUtf8(product.Title());
        price = ToUtf8(product.Price().FormattedPrice());
        if (product.IsInUserCollection()) {
          owned = true;
        }
      }
    } catch (...) {
    }

    try {
      auto kinds = ProductKinds();
      auto associated = context.GetAssociatedStoreProductsAsync(kinds.GetView()).get();
      available = true;
      for (auto const& pair : associated.Products()) {
        StoreProduct const product = pair.Value();
        if (!IsMonthlyProduct(product)) {
          continue;
        }
        product_found = true;
        if (title.empty()) {
          title = ToUtf8(product.Title());
        }
        if (price.empty()) {
          price = ToUtf8(product.Price().FormattedPrice());
        }
        if (product.IsInUserCollection()) {
          owned = true;
        }
      }
    } catch (...) {
    }

    try {
      auto kinds = ProductKinds();
      auto collection = context.GetUserCollectionAsync(kinds.GetView()).get();
      available = true;
      for (auto const& pair : collection.Products()) {
        StoreProduct const product = pair.Value();
        if (IsMonthlyProduct(product) && product.IsInUserCollection()) {
          owned = true;
          product_found = true;
        }
      }
    } catch (...) {
    }

    map[flutter::EncodableValue("available")] = available;
    map[flutter::EncodableValue("owned")] = owned;
    map[flutter::EncodableValue("productFound")] = product_found;
    if (!price.empty()) {
      map[flutter::EncodableValue("price")] = price;
    }
    if (!title.empty()) {
      map[flutter::EncodableValue("title")] = title;
    }
    if (!available) {
      map[flutter::EncodableValue("message")] = std::string(kNotListed);
    }
  } catch (winrt::hresult_error const&) {
    return UnavailableMap(kNotListed);
  } catch (...) {
    return UnavailableMap(kNotListed);
  }
  return map;
}

void ReplyPurchase(flutter::MethodResult<flutter::EncodableValue>& result,
                   StorePurchaseStatus status,
                   bool product_found) {
  flutter::EncodableMap map;
  const bool owned = status == StorePurchaseStatus::Succeeded ||
                     status == StorePurchaseStatus::AlreadyPurchased;
  std::string code = "failed";
  std::string message = kNotListed;
  if (status == StorePurchaseStatus::Succeeded) {
    code = "succeeded";
    message = "You are on Pro.";
  } else if (status == StorePurchaseStatus::AlreadyPurchased) {
    code = "already_purchased";
    message = "This Microsoft account already has Pro.";
  } else if (status == StorePurchaseStatus::NotPurchased) {
    code = "canceled";
    message = "Purchase cancelled.";
  } else if (product_found) {
    message = "The Microsoft Store could not complete that purchase.";
  }
  map[flutter::EncodableValue("available")] = true;
  map[flutter::EncodableValue("owned")] = owned;
  map[flutter::EncodableValue("productFound")] = product_found;
  map[flutter::EncodableValue("status")] = code;
  map[flutter::EncodableValue("message")] = message;
  result.Success(flutter::EncodableValue(map));
}

}  // namespace

class StoreIapBridge::Impl {
 public:
  Impl(flutter::BinaryMessenger* messenger, HWND hwnd) : hwnd_(hwnd) {
    channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, "studygrove/windows_store",
        &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                   result) { Handle(call, std::move(result)); });
  }

  ~Impl() {
    if (channel_) {
      channel_->SetMethodCallHandler(nullptr);
    }
  }

 private:
  void Handle(const flutter::MethodCall<flutter::EncodableValue>& call,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                  result) {
    if (call.method_name() == "query") {
      Query(std::move(result));
      return;
    }
    if (call.method_name() == "purchase") {
      Purchase(std::move(result));
      return;
    }
    result->NotImplemented();
  }

  void Query(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
    std::thread([result = std::move(result)]() mutable {
      try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
        auto map = QueryStore();
        result->Success(flutter::EncodableValue(map));
        winrt::uninit_apartment();
      } catch (...) {
        result->Success(flutter::EncodableValue(UnavailableMap(kNotListed)));
      }
    }).detach();
  }

  void Purchase(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                    result) {
    try {
      auto context = StoreContext::GetDefault();
      BindContextToWindow(context, hwnd_);
      // Do not .get() other Store async calls on the UI thread (STA deadlock).
      auto op = context.RequestPurchaseAsync(kProductIdentity);
      op.Completed(
          [result = std::move(result)](
              winrt::Windows::Foundation::IAsyncOperation<
                  winrt::Windows::Services::Store::StorePurchaseResult> const&
                  async,
              AsyncStatus const status) mutable {
            if (status != AsyncStatus::Completed) {
              result->Success(flutter::EncodableValue(UnavailableMap(kNotListed)));
              return;
            }
            try {
              auto purchase = async.GetResults();
              ReplyPurchase(*result, purchase.Status(), true);
            } catch (...) {
              result->Success(
                  flutter::EncodableValue(UnavailableMap(kNotListed)));
            }
          });
    } catch (winrt::hresult_error const&) {
      result->Success(flutter::EncodableValue(UnavailableMap(kNotListed)));
    } catch (...) {
      result->Success(flutter::EncodableValue(UnavailableMap(kNotListed)));
    }
  }

  HWND hwnd_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

StoreIapBridge::StoreIapBridge(flutter::BinaryMessenger* messenger, HWND hwnd)
    : impl_(std::make_unique<Impl>(messenger, hwnd)) {}

StoreIapBridge::~StoreIapBridge() = default;
