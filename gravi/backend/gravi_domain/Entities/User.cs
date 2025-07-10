using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_domain.Entities
{
    public class User
    {
        public long? UserId { get; init; }
        public required Person Person { get; set; }

        [Length(2,50, ErrorMessage = "Length need to be in the range of 2-50 characters only.")]
        public required string Username { get; set; }
        public string? PhoneNumber { get; set; }
        [EmailAddress(ErrorMessage = "Invalid email address.")]
        public required string Email { get; set; }
        public required bool IsEmailVerified { get; set; } = false;
        public required string Password { get; set; }
        public required short Status { get; set; }

    }
}
