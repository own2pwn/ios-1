import UIKit
import TKUIKit
import SnapKit

final class SignerSignView: UIView, ConfigurableView {
  
  let scrollView = UIScrollView()
  let contentView = UIView()
  
  let fistStepView = SignerSignStepView()
  let qrCodeView = TKFancyQRCodeView()
  let secondStepView = SignerSignStepView()
  let thirdStepView = SignerSignStepView()
  let scannerContainerView = UIView()
  
  struct Model {
    let firstStepModel: SignerSignStepView.Model
    let secondStepModel: SignerSignStepView.Model
    let thirdStepModel: SignerSignStepView.Model
    let qrCodeModel: TKFancyQRCodeView.Model
  }
  
  func configure(model: Model) {
    fistStepView.configure(model: model.firstStepModel)
    secondStepView.configure(model: model.secondStepModel)
    thirdStepView.configure(model: model.thirdStepModel)
    qrCodeView.configure(model: model.qrCodeModel)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func embedScannerView(_ scannerView: UIView) {
    scannerContainerView.addSubview(scannerView)
    scannerView.snp.makeConstraints { make in
      make.edges.equalTo(scannerContainerView)
    }
  }
}

private extension SignerSignView {
  func setup() {
    backgroundColor = .Background.page
    scannerContainerView.backgroundColor = .black
    scannerContainerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    scannerContainerView.layer.cornerRadius = 16
    
    qrCodeView.color = UIColor(hex: "FFE26B")
    
    addSubview(scrollView)
    scrollView.addSubview(contentView)
    
    contentView.addSubview(fistStepView)
    contentView.addSubview(qrCodeView)
    contentView.addSubview(secondStepView)
    contentView.addSubview(thirdStepView)
    contentView.addSubview(scannerContainerView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    contentView.snp.makeConstraints { make in
      make.top.bottom.equalTo(scrollView)
      make.left.equalTo(scrollView).offset(16)
      make.right.equalTo(scrollView).offset(-16)
      make.width.equalTo(scrollView).inset(16).priority(.high)
    }
    
    fistStepView.snp.makeConstraints { make in
      make.top.equalTo(contentView).offset(16)
      make.left.right.equalTo(contentView)
    }
    
    qrCodeView.snp.makeConstraints { make in
      make.left.right.equalTo(contentView)
      make.top.equalTo(fistStepView.snp.bottom).offset(16)
    }
    
    secondStepView.snp.makeConstraints { make in
      make.left.right.equalTo(contentView)
      make.top.equalTo(qrCodeView.snp.bottom).offset(16)
    }
    
    thirdStepView.snp.makeConstraints { make in
      make.left.right.equalTo(contentView)
      make.top.equalTo(secondStepView.snp.bottom).offset(16)
    }
    
    scannerContainerView.snp.makeConstraints { make in
      make.top.equalTo(thirdStepView.snp.bottom)
      make.left.right.equalTo(contentView)
      make.height.equalTo(scannerContainerView.snp.width)
      make.bottom.equalTo(contentView).offset(-16)
    }
  }
}
