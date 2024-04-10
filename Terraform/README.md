### Check out my article on "How to determine the last accessed date of AWS S3 Buckets"
https://medium.com/@kennyangjy/how-to-determine-the-last-accessed-date-of-AWS-S3-Buckets-dd77d56ea9cf

![Be notified of dormant S3 Buckets](../S3_Last_Accessed.jpg?raw=true "Be notified of dormant S3 Buckets")

---
### To provision the resources in this repository:
1. `git clone https://github.com/Kenny-AngJY/last-accessed-date-AWS-S3-Buckets.git`
2. Change directory to the **Terraform** folder <br> `cd Terraform`
3. Create a *var.tfvars* to store the "Email" & "S3PathAthenaQuery" variable 
<br> `echo "Email=\"abc@gmail.com\"" > var.tfvars`
<br> `echo "S3PathAthenaQuery=\"s3://athena-query-info/s3-access-logs-last-accessed-queries/\"" >> var.tfvars`
4. `terraform init`
5. `terraform plan -var-file=var.tfvars`
<br> There will be 6 resources to be created.
6. `terraform apply -var-file=var.tfvars` <br>
As no backend is defined, the default backend will be local.
7. An email will be sent to you from AWS Notifications. Remember to confirm your email subscription to the SNS topic.

### Clean-up
1. `terraform destroy -var-file=var.tfvars`