import UIKit

final class GSLoginViewController: UIViewController {
    @IBOutlet weak var heightLabelError: NSLayoutConstraint!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var createAccountButton: UIButton!
    @IBOutlet weak var showPasswordButton: UIButton!
    
    var showPassword = true
    var errorInLogin = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        verifyLogin()
        
#if DEBUG
        configureTextFieldWithDefaultValue()
#endif
        
        setupView()
        validateButton()
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func verifyLogin() {
        if let _ = UserDefaultsManager.UserInfos.shared.readSesion() {
            configureRootViewController(with: HomeViewController())
        }
    }
    
    @IBAction func loginButton(_ sender: Any) {
        if !ConnectivityManager.shared.isConnected {
            Globals.showNoInternetCOnnection(
                controller: self)
            return
        }
        makeAuthenticationRequest()
    }
    
    @IBAction func showPassword(_ sender: Any) {
        checkIfshouldShowOrHiddenPassword()
        showPassword.toggle()
    }
    
    @IBAction func resetPasswordButton(_ sender: Any) {
        let storyboard = UIStoryboard(name: "GSUser", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "GSResetPasswordViewController") as! GSResetPasswordViewController
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
    
    
    @IBAction func createAccountButton(_ sender: Any) {
        let controller = GSCreateAccountViewController()
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }
}

// MARK: - Comportamentos de layout
extension GSLoginViewController {
    
    func setupView() {
        heightLabelError.constant = 0
        loginButton.layer.cornerRadius = loginButton.frame.height / 2
        loginButton.backgroundColor = .blue
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.isEnabled = true
        
        showPasswordButton.tintColor = .lightGray
        
        createAccountButton.layer.cornerRadius = createAccountButton.frame.height / 2
        createAccountButton.layer.borderWidth = 1
        createAccountButton.layer.borderColor = UIColor.blue.cgColor
        createAccountButton.setTitleColor(.blue, for: .normal)
        createAccountButton.backgroundColor = .white
        
        emailTextField.setDefaultColor()
        passwordTextField.setDefaultColor()
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didClickView))
        view.addGestureRecognizer(gesture)
        view.isUserInteractionEnabled = true
        validateButton()
    }
    
    @objc
    func didClickView() {
        view.endEditing(true)
    }
    
    //email
    @IBAction func emailBeginEditing(_ sender: Any) {
        if errorInLogin {
            resetErrorLogin(emailTextField)
        } else {
            emailTextField.setEditingColor()
        }
    }
    
    @IBAction func emailEditing(_ sender: Any) {
        validateButton()
    }
    
    @IBAction func emailEndEditing(_ sender: Any) {
        emailTextField.setDefaultColor()
    }
    
    //senha
    @IBAction func passwordBeginEditing(_ sender: Any) {
        if errorInLogin {
            resetErrorLogin(passwordTextField)
        } else {
            passwordTextField.setEditingColor()
        }
    }
    
    @IBAction func passwordEditing(_ sender: Any) {
        validateButton()
    }
    
    @IBAction func passwordEndEditing(_ sender: Any) {
        passwordTextField.setDefaultColor()
    }
    
    func setErrorLogin(_ message: String) {
        errorInLogin = true
        heightLabelError.constant = 20
        errorLabel.text = message
        emailTextField.setErrorColor()
        passwordTextField.setErrorColor()
    }
    
    func resetErrorLogin(_ textField: UITextField) {
        heightLabelError.constant = 0
        if textField == emailTextField {
            emailTextField.setEditingColor()
            passwordTextField.setDefaultColor()
        } else {
            emailTextField.setDefaultColor()
            passwordTextField.setDefaultColor()
        }
    }
}

extension GSLoginViewController {
    
    func validateButton() {
        if !emailTextField.text!.contains(".") ||
            !emailTextField.text!.contains("@") ||
            emailTextField.text!.count <= 5 {
            disableButton()
        } else {
            if let atIndex = emailTextField.text!.firstIndex(of: "@") {
                let substring = emailTextField.text![atIndex...]
                if substring.contains(".") {
                    enableButton()
                } else {
                    disableButton()
                }
            } else {
                disableButton()
            }
        }
    }
    
    func disableButton() {
        loginButton.backgroundColor = .gray
        loginButton.isEnabled = false
    }
    
    func enableButton() {
        loginButton.backgroundColor = .blue
        loginButton.isEnabled = true
    }
}

private extension GSLoginViewController {
    func configureTextFieldWithDefaultValue(
        emailTextField: String = "clean.code@devpass.com",
        passwordTextField: String = "111111") {
        self.emailTextField.text = emailTextField
        self.passwordTextField.text = passwordTextField
    }
    
    func configureRootViewController(with rootViewController: UIViewController) {
        let viewController = UINavigationController(rootViewController: rootViewController)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
    }
    
    func configureAlerView(title: String, message: String) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        let action = UIAlertAction(
            title: "Ok",
            style: .default
        )
        alertController.addAction(action)
        present(alertController, animated: true)
    }
    
    func makeAuthenticationRequest() {
        showLoading()
        let parameters = getParameters()
        let endpoint = Endpoints.Auth.login
        AF.request(endpoint, method: .get, parameters: parameters, headers: nil) { [weak self] result in
            guard let self = self else { return }
            self.handleResponseResult(result: result)
        }
    }
    
    
    func getParameters() -> [String: String] {
        let parameters: [String: String] = ["email": emailTextField.text ?? "",
                                            "password": passwordTextField.text ?? ""]
        return parameters
    }
    
    func handleResponseResult(result: Result<Data, Error>) {
        DispatchQueue.main.async {
            self.stopLoading()
            switch result {
            case .success(let data):
                self.decodeFrom(data: data)
            case .failure:
                self.showErrorMessage()
            }
        }
    }
    
    func decodeFrom(data: Data) {
        let decoder = JSONDecoder()
        if let session = try? decoder.decode(Session.self, from: data) {
            configureRootViewController(with: HomeViewController())
            UserDefaultsManager.UserInfos.shared.save(session: session, user: nil)
        } else {
            showErrorMessage()
        }
    }
    
    func showErrorMessage() {
        self.setErrorLogin("E-mail ou senha incorretos")
        self.configureAlerView(
            title: "Ops..",
            message: "Houve um problema, tente novamente mais tarde."
        )
    }
    
    func checkIfshouldShowOrHiddenPassword() {
        if(showPassword == true) {
            configureTextFieldSecureTextEntry(isSecureTextEntry: false)
            configureImageButton(imageName: "eye.slash")
        } else {
            configureTextFieldSecureTextEntry(isSecureTextEntry: true)
            configureImageButton(imageName: "eye")
        }
    }
    
    
    func configureTextFieldSecureTextEntry(isSecureTextEntry: Bool) {
        passwordTextField.isSecureTextEntry = isSecureTextEntry
    }
    
    func configureImageButton(imageName: String) {
        showPasswordButton.setImage(UIImage.init(systemName: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
    }
}
