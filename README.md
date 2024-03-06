### Check out my article on "How to determine the last accessed date of AWS S3 Buckets"
https://medium.com/@kennyangjy/how-to-determine-the-last-accessed-date-of-AWS-S3-Buckets-dd77d56ea9cf

![Be notified of dormant S3 Buckets](./S3_Last_Accessed.jpg?raw=true "Be notified of dormant S3 Buckets")

### To provision the resources in this repository:
1. `git clone https://github.com/Kenny-AngJY/last-accessed-date-AWS-S3-Buckets.git`
2. Change directory to the **Terraform** folder <br> `cd Terraform`
3. Create a terraform.tfvars to store the "Email" variable <br> `echo "Email=\"abc@gmail.com\"" > terraform.tfvars`
4. `terraform init`
5. `terraform plan`
6. `terraform apply` <br>
As no backend is defined, the default backend will be local.

### Clean-up
1. `terraform destroy`