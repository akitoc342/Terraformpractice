# Terraformを使用したリソースの作成
## 概要  
- Terraformを使用して可用性を意識したAWSリソースを作成する。
### 作成したテンプレートの説明 （使用サービス）
- appserver.tf・・AutoScalingの起動テンプレート、AutoScalingグループ、ポリシー、Parameter Store、keypairの登録
- data.tf・・AMI情報  
- rds.tf・・RDSの設定
- elb.tf・・ALBの設定、ターゲットグループの設定  
- iam.tf・・IAMポリシー、プロファイル情報  
- main.tf・・使用するTerraformのバージョンを指定  
- network.tf・・VPC、サブネットの設定情報  
- securty_group.tf・・セキュリティーグループの設定  
- terraform.tfvars・・環境変数の設定  

### 動作概要  
- AutoScalingポリシーによりEC2のCPU負荷が70%超えたらEC2を１台増やす  
- EC2のCPU負荷が5%以下ならEC2を１台減らす  
- RDSはマルチAZ構成で作成し、トラブル時にスタンバイインスタンスに自動で切り替わる構成で構築

## AWS構成図  
![Terraformリソース作成構成図](terraform.png)