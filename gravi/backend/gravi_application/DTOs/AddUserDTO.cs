using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.DTOs
{
    public class AddUserDTO
    {
        public required PersonDTO Person { get; set; }

        [StringLength(50, MinimumLength = 2, ErrorMessage = "Length needs to be in the range of 2-50 characters only.")]
        public required string Username { get; set; }

        [StringLength(20, MinimumLength = 2, ErrorMessage = "Length needs to be in the range of 2-20 characters only.")]
        public string? PhoneNumber { get; set; }

        [EmailAddress(ErrorMessage = "Invalid email address.")]
        public required string Email { get; set; }

        [RegularExpression(@"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{6,}$",
        ErrorMessage = "Password must be at least 6 characters long and contain at least one upper and lower case characters and one number.")]
        public required string Password { get; set; }

        [Compare("Password", ErrorMessage = "Password not matched in the verification...")]
        public required string PasswordMatch { get; set; }
    }

}
